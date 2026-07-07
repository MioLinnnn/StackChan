/*
SPDX-FileCopyrightText: 2026 M5Stack Technology CO LTD
SPDX-License-Identifier: MIT
*/

package service

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"time"
	v2 "stackChan/api/user/v2"
	"stackChan/internal/dao"
	"stackChan/internal/model/entity"

	"github.com/gogf/gf/v2/errors/gcode"
	"github.com/gogf/gf/v2/errors/gerror"
	"github.com/gogf/gf/v2/frame/g"
	"github.com/gogf/gf/v2/util/guid"
	"github.com/golang-jwt/jwt/v5"
)

const (
	TokenExpire = 365 * 24 * time.Hour
)

// hashPassword SHA-256 哈希密码
func hashPassword(password string) string {
	h := sha256.Sum256([]byte(password))
	return hex.EncodeToString(h[:])
}

// Login 本地登录验证
func Login(ctx context.Context, req *v2.LoginReq) (res *v2.LoginRes, err error) {
	if req.Username == "" || req.Password == "" {
		return nil, gerror.NewCode(gcode.CodeMissingParameter, "Username / Password cannot be left blank.")
	}

	// 查本地用户
	user, err := dao.User.Ctx(ctx).Where("username", req.Username).One()
	if err != nil {
		return nil, gerror.WrapCode(gcode.CodeDbOperationError, err, "Database query failed")
	}
	if user == nil {
		return nil, gerror.NewCode(gcode.CodeBusinessValidationFailed, "Invalid username or password")
	}

	// 验证密码
	var entity entity.User
	if err := user.Struct(&entity); err != nil {
		return nil, gerror.WrapCode(gcode.CodeInternalError, err, "Failed to parse user data")
	}

	// 取 password 字段（单独获取，因为 entity 里没有这个字段）
	storedPwd := user["password"].String()
	if storedPwd == "" || storedPwd != hashPassword(req.Password) {
		return nil, gerror.NewCode(gcode.CodeBusinessValidationFailed, "Invalid username or password")
	}

	// 更新最后在线时间
	dao.User.Ctx(ctx).Data(g.Map{"last_online": time.Now().UnixMilli()}).Where("uid", entity.Uid).Update()

	// 生成 token
	token, err := generateToken(ctx, entity.Uid)
	if err != nil {
		return nil, err
	}
	return &v2.LoginRes{
		Token: token,
	}, nil
}

// Registration 本地注册
func Registration(ctx context.Context, req *v2.RegistrationReq) (res *v2.RegistrationRes, err error) {
	if req.UserName == "" || req.Password == "" || req.Email == "" {
		return nil, gerror.NewCode(gcode.CodeMissingParameter, "Username/Email/Password cannot be empty")
	}

	// 检查用户名是否已存在
	count, err := dao.User.Ctx(ctx).Where("username", req.UserName).Count()
	if err != nil {
		return nil, gerror.WrapCode(gcode.CodeDbOperationError, err, "Database query failed")
	}
	if count > 0 {
		return nil, gerror.NewCode(gcode.CodeBusinessValidationFailed, "Username already exists")
	}

	now := time.Now()
	uid := now.UnixMilli()

	// 插入用户
	_, err = dao.User.Ctx(ctx).Insert(g.Map{
		"uid":          uid,
		"username":     req.UserName,
		"userslug":     req.UserName,
		"display_name": req.UserName,
		"password":     hashPassword(req.Password),
		"join_date":    now.UnixMilli(),
		"last_online":  now.UnixMilli(),
		"user_status":  "online",
		"create_at":    now,
		"update_at":    now,
	})
	if err != nil {
		return nil, gerror.WrapCode(gcode.CodeDbOperationError, err, "Failed to create user")
	}

	return nil, nil
}

// generateToken 生成 JWT token
func generateToken(ctx context.Context, uid int64) (string, error) {
	now := time.Now()

	claims := jwt.MapClaims{
		"jti": guid.S(),
		"id":  uid,
		"iss": "stackchan-local",
		"aud": "stackchan-local",
		"iat": now.Unix(),
		"exp": now.Add(TokenExpire).Unix(),
	}
	tokenObj := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	jwtSecret := GetJwtSecret()
	if jwtSecret == "" || len(jwtSecret) < 16 {
		return "", gerror.NewCode(gcode.CodeInternalError, "JWT secret is empty or too weak")
	}
	token, err := tokenObj.SignedString([]byte(jwtSecret))
	if err != nil {
		return "", gerror.WrapCode(gcode.CodeInternalError, err, "Failed to generate token")
	}
	return token, nil
}

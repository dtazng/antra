package main

import (
	"context"
	"fmt"
	"os"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"

	internalauth "antra/backend/internal/auth"
	"antra/backend/internal/pullhandler"
)

func main() {
	cfg, err := config.LoadDefaultConfig(context.Background())
	if err != nil {
		panic(fmt.Sprintf("unable to load AWS config: %v", err))
	}

	region := os.Getenv("AWS_REGION")
	if region == "" {
		region = "us-east-1"
	}
	poolID := os.Getenv("COGNITO_USER_POOL_ID")
	jwksURL := fmt.Sprintf(
		"https://cognito-idp.%s.amazonaws.com/%s/.well-known/jwks.json",
		region, poolID,
	)
	if err := internalauth.SetJWKSURL(jwksURL); err != nil {
		panic(fmt.Sprintf("failed to initialise JWKS: %v", err))
	}

	h := &pullhandler.Handler{
		Dynamo:    dynamodb.NewFromConfig(cfg),
		TableName: os.Getenv("TABLE_NAME"),
	}
	lambda.Start(h.Handle)
}

import * as path from 'path';
import * as cdk from 'aws-cdk-lib';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import * as cognito from 'aws-cdk-lib/aws-cognito';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import { Construct } from 'constructs';

export class AntraStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // -------------------------------------------------------------------------
    // DynamoDB — single-table design
    // -------------------------------------------------------------------------
    const syncTable = new dynamodb.Table(this, 'AntraSyncTable', {
      tableName: 'antra_sync',
      partitionKey: { name: 'pk', type: dynamodb.AttributeType.STRING },
      sortKey:      { name: 'sk', type: dynamodb.AttributeType.STRING },
      billingMode:  dynamodb.BillingMode.PAY_PER_REQUEST,
      timeToLiveAttribute: 'ttl',
      removalPolicy: cdk.RemovalPolicy.RETAIN,
      pointInTimeRecovery: true,
    });

    // GSI1: (userId, updatedAt) — used by pull_sync delta queries
    syncTable.addGlobalSecondaryIndex({
      indexName: 'GSI1',
      partitionKey: { name: 'userId',    type: dynamodb.AttributeType.STRING },
      sortKey:      { name: 'updatedAt', type: dynamodb.AttributeType.STRING },
      projectionType: dynamodb.ProjectionType.ALL,
    });

    // -------------------------------------------------------------------------
    // Cognito User Pool
    // -------------------------------------------------------------------------
    const userPool = new cognito.UserPool(this, 'AntraUserPool', {
      userPoolName: 'antra-users',
      selfSignUpEnabled: true,
      signInAliases: { email: true },
      autoVerify: { email: true },
      passwordPolicy: {
        minLength: 8,
        requireLowercase: true,
        requireUppercase: true,
        requireDigits: true,
        requireSymbols: false,
      },
      accountRecovery: cognito.AccountRecovery.EMAIL_ONLY,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });

    const userPoolClient = userPool.addClient('AntraFlutterClient', {
      userPoolClientName: 'antra-flutter',
      authFlows: {
        userPassword: true,
        userSrp: true,
      },
      oAuth: {
        flows: { authorizationCodeGrant: true },
        scopes: [cognito.OAuthScope.OPENID, cognito.OAuthScope.EMAIL],
        callbackUrls: ['antra://callback'],
        logoutUrls:   ['antra://logout'],
      },
      supportedIdentityProviders: [
        cognito.UserPoolClientIdentityProvider.COGNITO,
        // Apple and Google providers are added after federation is configured.
      ],
      preventUserExistenceErrors: true,
    });

    // -------------------------------------------------------------------------
    // Shared Lambda environment
    // No Lambda layers needed — Go compiles all internal/ packages into each
    // binary. Run `make build` in backend/ before `cdk deploy`.
    // -------------------------------------------------------------------------
    const commonEnv: Record<string, string> = {
      TABLE_NAME:            syncTable.tableName,
      COGNITO_USER_POOL_ID:  userPool.userPoolId,
      COGNITO_CLIENT_ID:     userPoolClient.userPoolClientId,
    };

    // -------------------------------------------------------------------------
    // Lambda functions — Go 1.22+ on provided.al2023 ARM64 (Graviton2)
    // Binaries produced by: make build → dist/pull_sync/bootstrap
    //                                    dist/push_sync/bootstrap
    // -------------------------------------------------------------------------
    const pullFn = new lambda.Function(this, 'SyncPullFunction', {
      functionName: 'antra-sync-pull',
      runtime:      lambda.Runtime.PROVIDED_AL2023,
      architecture: lambda.Architecture.ARM_64,
      handler:      'bootstrap', // Go binary convention for provided runtimes
      code:         lambda.Code.fromAsset(
        path.join(__dirname, '..', 'dist', 'pull_sync'),
      ),
      memorySize:  512,
      timeout:     cdk.Duration.seconds(10),
      environment: commonEnv,
    });
    syncTable.grantReadData(pullFn);

    const pushFn = new lambda.Function(this, 'SyncPushFunction', {
      functionName: 'antra-sync-push',
      runtime:      lambda.Runtime.PROVIDED_AL2023,
      architecture: lambda.Architecture.ARM_64,
      handler:      'bootstrap',
      code:         lambda.Code.fromAsset(
        path.join(__dirname, '..', 'dist', 'push_sync'),
      ),
      memorySize:  1024,
      timeout:     cdk.Duration.seconds(10),
      environment: commonEnv,
    });
    syncTable.grantReadWriteData(pushFn);

    // -------------------------------------------------------------------------
    // API Gateway
    // -------------------------------------------------------------------------
    const api = new apigateway.RestApi(this, 'AntraSyncApi', {
      restApiName: 'antra-sync',
      description: 'Antra Log sync API',
      defaultCorsPreflightOptions: {
        allowOrigins: apigateway.Cors.ALL_ORIGINS,
        allowMethods: apigateway.Cors.ALL_METHODS,
        allowHeaders: ['Content-Type', 'Authorization'],
      },
      deployOptions: {
        stageName: 'prod',
        throttlingBurstLimit: 100,
        throttlingRateLimit:  50,
      },
    });

    const authorizer = new apigateway.CognitoUserPoolsAuthorizer(
      this,
      'CognitoAuthorizer',
      {
        cognitoUserPools: [userPool],
        authorizerName: 'antra-cognito-auth',
      },
    );

    const authOptions: apigateway.MethodOptions = {
      authorizer,
      authorizationType: apigateway.AuthorizationType.COGNITO,
    };

    const syncResource = api.root.addResource('sync');
    syncResource
      .addResource('pull')
      .addMethod('POST', new apigateway.LambdaIntegration(pullFn), authOptions);
    syncResource
      .addResource('push')
      .addMethod('POST', new apigateway.LambdaIntegration(pushFn), authOptions);

    // -------------------------------------------------------------------------
    // Stack outputs (written to outputs.json via cdk deploy --outputs-file)
    // -------------------------------------------------------------------------
    new cdk.CfnOutput(this, 'ApiGatewayUrl', {
      value:       api.url,
      exportName:  'AntraApiGatewayUrl',
      description: 'Base URL for the Antra sync REST API',
    });

    new cdk.CfnOutput(this, 'CognitoUserPoolId', {
      value:       userPool.userPoolId,
      exportName:  'AntraCognitoUserPoolId',
      description: 'Cognito User Pool ID for Amplify Auth configuration',
    });

    new cdk.CfnOutput(this, 'CognitoUserPoolClientId', {
      value:       userPoolClient.userPoolClientId,
      exportName:  'AntraCognitoUserPoolClientId',
      description: 'Cognito User Pool Client ID for Amplify Auth configuration',
    });

    new cdk.CfnOutput(this, 'DynamoDbTableName', {
      value:       syncTable.tableName,
      exportName:  'AntraDynamoDbTableName',
      description: 'DynamoDB table name for direct access in tests',
    });
  }
}

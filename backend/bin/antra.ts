#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { AntraStack } from '../lib/antra-stack';

const app = new cdk.App();

new AntraStack(app, 'AntraStack', {
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION ?? 'us-east-1',
  },
  description: 'Antra Log — sync backend (DynamoDB, Lambda, Cognito, API Gateway)',
});

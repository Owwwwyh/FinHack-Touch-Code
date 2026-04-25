/**
 * aws_config.js
 *
 * AWS SDK v3 client initialization.
 */

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { EventBridgeClient } from "@aws-sdk/client-eventbridge";

const region = process.env.AWS_REGION || 'ap-southeast-1';

export const dynamoClient = new DynamoDBClient({ region });
export const ebClient = new EventBridgeClient({ region });

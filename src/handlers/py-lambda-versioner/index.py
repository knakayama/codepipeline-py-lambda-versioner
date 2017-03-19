from __future__ import print_function
from zipfile import ZipFile
from botocore.client import ClientError, Config
import boto3
import json

OUTPUT_ZIP_PATH = '/tmp/deploy-output.zip'
OUTPUT_JSON_PATH = 'deploy-output.json'
codepipeline = boto3.client('codepipeline')


def extract_file():
    with ZipFile(OUTPUT_ZIP_PATH) as zip:
        with zip.open(OUTPUT_JSON_PATH) as f:
            return json.loads(f.read())


def send_fail(job_id, message):
    codepipeline.put_job_failure_result(
            jobId=job_id,
            failureDetails={'type': 'JobFailed', 'message': message}
            )


def handler(event, context):
    print(event)

    job_id = event['CodePipeline.job']['id']
    bucket_name = event['CodePipeline.job']['data']['inputArtifacts'][0]['location']['s3Location']['bucketName']
    object_key = event['CodePipeline.job']['data']['inputArtifacts'][0]['location']['s3Location']['objectKey']
    try:
        boto3.resource('s3', config=Config(signature_version='s3v4')).meta.client.download_file(bucket_name, object_key, OUTPUT_ZIP_PATH)
    except ClientError as e:
        send_fail(job_id, e.response['Error'])
        return

    deploy_output = extract_file()
    for func_arn in deploy_output.keys():
        try:
            boto3.client('lambda').publish_version(FunctionName=deploy_output[func_arn])
        except ClientError as e:
            send_fail(job_id, e.response['Error'])
            return
    codepipeline.put_job_success_result(jobId=job_id)
    return event

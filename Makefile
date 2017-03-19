S3_BUCKET = _YOUR_S3_BUCKET_
REGION = _YOUR_AWS_REGION_
STACK_NAME = codepipeline-py-lambda-versioner

package:
	@[ -d .sam ] || mkdir .sam
	@aws cloudformation package \
		--template-file sam.yml \
		--s3-bucket $(S3_BUCKET) \
		--output-template-file .sam/packaged.yml \
		--region $(REGION)

deploy:
	@if [ -f params/param.json ]; then \
		aws cloudformation deploy \
			--template-file .sam/packaged.yml \
			--stack-name $(STACK_NAME) \
			--capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
			--parameter-overrides `cat params/param.json | jq -r '.Parameters | to_entries | map("\(.key)=\(.value|tostring)") | .[]' | tr '\n' ' ' | awk '{print}'` \
			--no-execute-changeset \
			--region $(REGION); \
	else \
		aws cloudformation deploy \
			--template-file .sam/packaged.yml \
			--stack-name $(STACK_NAME) \
			--capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
			--no-execute-changeset \
			--region $(REGION); \
	fi

execute-changeset:
	@aws cloudformation execute-change-set \
		--stack-name $(STACK_NAME) \
		--change-set-name `aws cloudformation list-change-sets \
			--stack-name $(STACK_NAME) \
			--query 'reverse(sort_by(Summaries,&CreationTime))[0].ChangeSetName' \
			--output text \
			--region $(REGION)` \
		--region $(REGION)

all: package deploy execute-changeset

.PHONY: package deploy execute-changeset all

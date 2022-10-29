build:
	GOOS=linux GOARCH=amd64 go build -o infra/build/bin/app .

init:
	terraform -chdir=infra init

plan:
	terraform -chdir=infra plan

apply:
	terraform -chdir=infra apply --auto-approve

destroy:
	terraform -chdir=infra destroy --auto-approve

deploy: build apply
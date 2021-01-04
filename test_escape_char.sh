#!/bin/bash

function enable_secret(){
        org_secrets=(CLOUD_CI_SLACK_URL CLOUD_ECR_ACCESS_KEY CLOUD_ECR_SECRET_KEY CLOUD_GITOPS_REPO_KEY)
        repo_id=$(curl -H "Accept: application/vnd.github.v3+json"  https://${uname}:${secret}@api.github.com/repos/pixellot/${repo_name})

        for org_secret in ${org_secrets[@]}
        do
          curl -X PUT -H "Accept: application/vnd.github.v3+json"  "https://${uname}:${secret}@api.github.com/orgs/pixellot/actions/secrets/${org_secret}/repositories/${repo_id}"
        done
}

function print_message(){
    echo
    echo ">>>>>>>>>>>>>>> $1"
    echo
}

function download_package(){
  if ! command -v $1 > /dev/null   # Check if bc in $PATH, if not download it.
        then
                print_message "$1 cannot be found on PATH, installing $1 ...."
                apt-get update && apt-get install -y $1
fi
}

# read -p 'Type in Github repository name to Update: ' repo_name   ######################3
# read -p 'Type in Github PAT(personal access token): ' secret
# read -p 'Type in your Github user name: ' uname
repo_name=venue-metrics-rest
secret=9b9fad01d22443ff5bed3003bb5131b773acb444
uname=hroyg


# Create tmp WorkDir
workspace=$(mktemp -d workspace_${repo_name}.XXXX)
print_message "Workspace dir in -> /tmp/${workspace}"
cd ${workspace}

# Install bc and expect
download_package bc
download_package expect


# Clone Github repo
print_message "Cloning repository github.com/Pixellot/${repo_name}.git:"
git clone https://${uname}:${secret}@github.com/Pixellot/${repo_name}.git 
cd ${repo_name}

# Jest
print_message "Configuring Jest:"
cat <<EOF >script.exp
#!/usr/bin/expect -f
set timeout -1
spawn npx jest --init
match_max 100000
expect "\[4mThe following questions will help Jest to create a suitable configuration for your project\[24m\r
\[4m\[24m\r
\[?25l\[2K\[1G\[36m?\[39m \[1mWould you like to use Jest when running \"test\" script in \"package.json\"?\[22m \[90m›\[39m \[90m(Y/n)\[39m"
send -- "y"
expect -exact "\[2K\[G\[2K\[1G\[32m✔\[39m \[1mWould you like to use Jest when running \"test\" script in \"package.json\"?\[22m \[90m…\[39m yes\r
\[?25h\[?25l\[2K\[1G\[36m?\[39m \[1mWould you like to use Typescript for the configuration file?\[22m \[90m›\[39m \[90m(y/N)\[39m"
send -- "n"
expect -exact "\[2K\[G\[2K\[1G\[32m✔\[39m \[1mWould you like to use Typescript for the configuration file?\[22m \[90m…\[39m no\r
\[?25h\[?25l\[36m?\[39m \[1mChoose the test environment that will be used for testing\[22m \[90m›\[39m \[90m- Use arrow-keys. Return to submit.\[39m\r
\[36m❯\[39m   \[36m\[4mnode\[39m\[24m\[90m\[39m\r
    jsdom (browser-like)\[90m\[39m\r
"
send -- "\r"
expect -exact "\[2K\[1A\[2K\[1A\[2K\[1A\[2K\[G\[32m✔\[39m \[1mChoose the test environment that will be used for testing\[22m \[90m›\[39m node\r
\[?25h\[?25l\[2K\[1G\[36m?\[39m \[1mDo you want Jest to add coverage reports?\[22m \[90m›\[39m \[90m(y/N)\[39m"
send -- "y"
expect -exact "\[2K\[G\[2K\[1G\[32m✔\[39m \[1mDo you want Jest to add coverage reports?\[22m \[90m…\[39m yes\r
\[?25h\[?25l\[36m?\[39m \[1mWhich provider should be used to instrument code for coverage?\[22m \[90m›\[39m \[90m- Use arrow-keys. Return to submit.\[39m\r
\[36m❯\[39m   \[36m\[4mv8\[39m\[24m\[90m\[39m\r
    babel\[90m\[39m\r
"
send -- "\[B"
expect -exact "\[2K\[1A\[2K\[1A\[2K\[1A\[2K\[G\[36m?\[39m \[1mWhich provider should be used to instrument code for coverage?\[22m \[90m›\[39m \[90m- Use arrow-keys. Return to submit.\[39m\r
    v8\[90m\[39m\r
\[36m❯\[39m   \[36m\[4mbabel\[39m\[24m\[90m\[39m\r
"
send -- "\r"
expect -exact "\[2K\[1A\[2K\[1A\[2K\[1A\[2K\[G\[32m✔\[39m \[1mWhich provider should be used to instrument code for coverage?\[22m \[90m›\[39m babel\r
\[?25h\[?25l\[2K\[1G\[36m?\[39m \[1mAutomatically clear mock calls and instances between every test?\[22m \[90m›\[39m \[90m(y/N)\[39m"
send -- "y"
expect eof
EOF

chmod +x ./script.exp

npm install --save-dev jest # install dev-dependencies in package.json
npx jest
#/usr/bin/expect  script.exp # wrapper for command "npx jest --init"
./script.exp # wrapper for command "npx jest --init"

rm script.exp

mkdir -p "__tests__" && touch "/__tests__/test.js"
cat <<EOF >__tests__/test.js
    const add = (a, b) => a + b;

    test('2 + 3 = 5', () => {
    expect(add(2, 3)).toBe(5);
    });
EOF

# Set --production flag
production_flag=$(grep -c "npm install --production" {dockerfile,Dockerfile} 2>/dev/null|cut -d ':' -f2|paste -s -d+ - |bc)
    if [ ${production_flag} -eq 0 ]
        then
            sed -i 's/RUN npm install/RUN npm install --production/' {dockerfile,Dockerfile}  2>/dev/null
        else
            print_message "Flag for running in production mode was already set."
    fi

# # Create ECR repo   ################################
# if aws ecr describe-repositories --region us-east-1 --repository-names cloud/${repo_name} 
#         then
#                 print_message "ECR repository already exists"
#         else    
#                 print_message "Creating ECR repository: cloud/${repo_name}:"
#                 aws ecr create-repository --repository-name cloud/${repo_name} --image-scanning-configuration scanOnPush=true --image-tag-mutability IMMUTABLE --region us-east-1
#  fi               


# Enable org secrets for repo
# enable_secret #####################################

# Update package.json and ignore files
echo -n "\n__tests__\ncoverage\njest.config.js" >>.dockerignore
echo -n "\n\n# Jest\ncoverage" >>.gitignore
sed 's/"version": .*/"version": "2.2.0"/' package.json


# Github actions CI files
print_message "Adding CI files:"
mkdir -p .github/workflows

cat <<EOF > .github/workflows/pr_nodejs_ci.yaml
# Triggers on:
# 1. Pull request
#
# Workflow:
# 1. Validate Dockerfile's Node.js version matches github runner's
# 2. Build and test the nodejs app


name: PR Node.js CI

on:
pull_request:


jobs:

test_job:
    name: Build and test
    runs-on: ubuntu-latest
    strategy:
    matrix:
        node-version: [12.x] # Make sure to test with the docker image's node js version
    steps:

    - uses: actions/checkout@v2
        
    - name: Compare Nodejs versions
    working-directory: \${{ github.workspace }}
    run: | 
        dockerfile_nodejs=\$(grep -s "FROM node:" {D,d}ockerfile | grep -o  "[[:digit:]]\+")
        runner_nodejs=\$(echo \${{ matrix.node-version }} | grep -o "[[:digit:]]\+")
        if [ \$dockerfile_nodejs -ne \$runner_nodejs ] ;then
        echo "Dockerfile and runner Nodejs versions mismatch (\$dockerfile_nodejs -> \$runner_nodejs), please update either one"
        fi
        
    - name: Use Node.js \${{ matrix.node-version }}
    uses: actions/setup-node@v1
    with:
        node-version: \${{ matrix.node-version }}

    - run: npm ci
    - run: npm run build --if-present
    - run: npm run test
EOF        



cat <<EOF > .github/workflows/push_nodejs_ci.yml
# Workflow:
# 1. On push to master ONLY:
#    a. Build a docker image and upload it to ECR
#    b. Update newly created image tag in he relevant kubernetes resource yaml in git, which in turn will trigger a kubernetes deployment
#    c. Set the Jira ticket to "in testing"
# 2. Send slack notification to report process results.

name: Push Node.js CI

on:
  push:
    branches: [ "master" ]
#    tags: [ "*-beta*", "*-stable*" ]


jobs:

  push_image_job:
    name: Upload to ECR
    runs-on: ubuntu-latest
    outputs:
      pxlt_image_tag: \${{ steps.create-version.outputs.image_tag }}
      pxlt_commit_hash: \${{ steps.create-version.outputs.commit_hash }}
    steps:

    - name: Checkout
      uses: actions/checkout@v2
      with:
        fetch-depth: 0

    - name: Create version for docker tag
      id: create-version
      shell: bash
      run: |
        PXLT_IMAGE_TAG=\$(git describe --tags --long)
        PXLT_DOCKER_LABEL=\$(echo "\${PXLT_IMAGE_TAG}" | awk -F"-|g" '{ print \$1"-"\$3"-"\$5}')
        PXLT_COMMIT_HASH=\$(echo "\${PXLT_IMAGE_TAG}" | sed s/.*g//g)
        echo "PXLT_IMAGE_TAG=\${PXLT_IMAGE_TAG}" >> \$GITHUB_ENV
        echo "PXLT_DOCKER_LABEL=\${PXLT_DOCKER_LABEL}" >> \$GITHUB_ENV
        echo "PXLT_COMMIT_HASH=\${PXLT_COMMIT_HASH}" >> \$GITHUB_ENV
        echo ::set-output name=image_tag::\$PXLT_IMAGE_TAG
        echo ::set-output name=commit_hash::\$PXLT_COMMIT_HASH

    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v1
      with:
        aws-access-key-id: \${{ secrets.CLOUD_ECR_ACCESS_KEY }}
        aws-secret-access-key: \${{ secrets.CLOUD_ECR_SECRET_KEY }}
        aws-region: us-east-1

    - name: Login to Amazon ECR
      id: login-ecr
      uses: aws-actions/amazon-ecr-login@v1
    
    - name: Get repo name
      id: extract-repo-name
      shell: bash
      run: |
        repo_name="\${GITHUB_REPOSITORY##*/}"
        echo "PXLT_ECR_REPOSITORY=cloud/\$repo_name" >> \$GITHUB_ENV

    - name: Find image in ECR
      id: find-image-in-ecr
      shell: bash
      continue-on-error: true # This step will fail if image doesnt exist but will be marked as successful because of "continue-on-error"
      run: |
        response="\$(aws ecr describe-images --repository-name=\${PXLT_ECR_REPOSITORY} --image-ids=imageTag=\${PXLT_COMMIT_HASH})"
        if [[ \$? == 0 ]]; then
            echo "Docker image \${PXLT_ECR_REPOSITORY}:\${PXLT_COMMIT_HASH} found in ECR"
            echo "Skipping build image step"
        fi

    - name: Build, tag and push image to Amazon ECR
      id: build-image
      env:
        ECR_REGISTRY: \${{ steps.login-ecr.outputs.registry }}
      if: steps.find-image-in-ecr.outcome == 'failure'
      run: |
        docker build -t \${ECR_REGISTRY}/\${PXLT_ECR_REPOSITORY}:\${PXLT_IMAGE_TAG} -t \${ECR_REGISTRY}/\${PXLT_ECR_REPOSITORY}:\${PXLT_COMMIT_HASH}  . --label "PXLT_VERSION=\${PXLT_DOCKER_LABEL}"
        docker push \${ECR_REGISTRY}/\${PXLT_ECR_REPOSITORY}:\${PXLT_IMAGE_TAG}
        docker push \${ECR_REGISTRY}/\${PXLT_ECR_REPOSITORY}:\${PXLT_COMMIT_HASH}
        echo "::set-output name=image::\${ECR_REGISTRY}/\${PXLT_ECR_REPOSITORY}:\${PXLT_IMAGE_TAG}"

    - name: Add additional tag to an existing ECR image
      id: add-additional-tag-to-existing-ecr-image
      if: steps.find-image-in-ecr.outcome == 'success' && startsWith(github.ref, 'refs/tags')
      run: |
        NEW_TAG=\$(echo \${{ github.ref }} | awk -F"/" '{print \$3}')

        MANIFEST=\$(aws ecr batch-get-image --repository-name \${PXLT_ECR_REPOSITORY} --image-ids imageTag=\${PXLT_COMMIT_HASH} --query 'images[].imageManifest' --output text)
        aws ecr put-image --repository-name \${PXLT_ECR_REPOSITORY} --image-tag \${NEW_TAG} --image-manifest "\${MANIFEST}"
  
  trigger_k8s_deploy_job:
    name: Trigger_k8s_deploy_job
    runs-on: ubuntu-latest
    outputs:
      repository_name: \${{ steps.update-image-tag-to-k8s.outputs.repository_name }}
    needs: push_image_job
    steps:
    
    - name: checkout k8s config
      id: checkout-k8s-config
      uses: actions/checkout@v2
      with:
        repository: pixellot/k8s-cloud-resources
        path: k8s-cloud-resources
        ssh-key: \${{ secrets.CLOUD_GITOPS_REPO_KEY }}

    - name: Update image tag to k8s config
      id: update-image-tag-to-k8s
      working-directory: \${{ github.workspace }}/k8s-cloud-resources/cloud-services/overlays/dev/
      run: |
        REPOSITORY_NAME=\${GITHUB_REPOSITORY##*/}
        PXLT_IMAGE_TAG=\${{ needs.push_image_job.outputs.pxlt_image_tag }}
        PXLT_COMMIT_HASH=\${{ needs.push_image_job.outputs.pxlt_commit_hash }}
        echo ::set-output name=repository_name::\$REPOSITORY_NAME  
        sed -i "s/newTag:.*/newTag: \$PXLT_IMAGE_TAG/" \${REPOSITORY_NAME}/kustomization.yaml
        cat \${REPOSITORY_NAME}/kustomization.yaml
        git config user.name \${{ github.actor }}
        git config user.email \${{ github.actor }}@pixellot.tv
        git add .
        git commit -m "CI-\${REPOSITORY_NAME}:\${PXLT_COMMIT_HASH}:\${{ github.event.head_commit.message }}" && git push || echo "No changes to commit"

  update_jira_job:
    name: Update JIRA
    runs-on: ubuntu-latest
    needs: trigger_k8s_deploy_job
    steps:

    - name: Setup
      uses: pixellot/gajira-cli@master
      with:
        version: 1.0.20

    - name: Checkout
      uses: actions/checkout@v2
      with:
        fetch-depth: 0

    - name: Login
      uses: atlassian/gajira-login@master
      env:
        JIRA_BASE_URL: \${{ secrets.JIRA_BASE_URL }}
        JIRA_USER_EMAIL: \${{ secrets.JIRA_USER_EMAIL }}
        JIRA_API_TOKEN: \${{ secrets.JIRA_API_TOKEN }}

    - name: Find issue in commit messages
      id: find-issue
      uses: atlassian/gajira-find-issue-key@master
      with:
        from: commits

    - name: Get git version for non DEV tickets
      id: get-version
      shell: bash
      if: "!contains(steps.find-issue.outputs.issue, 'DEV')"
      run: |
        pxlt_version=\$(git describe --tags --abbrev=0|awk '{split(\$0,a,"-"); print a[1]}')
        echo "pxlt_version: \$pxlt_version"
        echo "::set-output name=pxlt_version::\$pxlt_version"
        
    - name: Transition issue & Set version
      uses: Pixellot/gajira-transition@master
      with:
        issue: \${{ steps.find-issue.outputs.issue }}
        fixVersion: \${{ steps.get-version.outputs.pxlt_version }}
        transition: "In Testing"
  
  send_notification_job:
    name: Send notification
    runs-on: ubuntu-latest
    needs: update_jira_job
    if: always()
    steps:

    - name: Workflow status
      id: workflow-status
      uses: pixellot/workflow-status@master
      with:
        workflow_name:  \${{ github.workflow }}
        github_run_id: \${{ github.run_id }}
        github_repository: \${{ github.repository }}
        github_token: \${{ github.token }}
        
    - name: Generate failure msg
      id: generate-failure-msg
      shell: bash
      if: steps.workflow-Status.outputs.failed_job
      run: |
            echo ::set-output name=job::- Job:
            echo ::set-output name=step::- Step:
           
    - name: Slack notification
      uses: rtCamp/action-slack-notify@master
      env:
        SLACK_WEBHOOK: '\${{ secrets.CLOUD_CI_SLACK_URL }}'
        SLACK_CHANNEL: 'cloud-ci'
        SLACK_COLOR: '\${{ steps.workflow-Status.outputs.notification_color }}'
        SLACK_ICON: https://github.githubassets.com/images/modules/logos_page/Octocat.png?size=48
        SLACK_MESSAGE: "\${{ steps.workflow-Status.outputs.notification_icon }} Workflow \${{ steps.workflow-Status.outputs.workflow_result }}\n Commit Message: \${{ github.event.head_commit.message }}\n Github Repository: \${{ github.repository }}\n\${{ steps.generate-failure-msg.outputs.job }} \${{ steps.workflow-Status.outputs.failed_job }}\n\${{ steps.generate-failure-msg.outputs.step }} \${{ steps.workflow-Status.outputs.failed_step }}"
        SLACK_TITLE: 'Status:'
        SLACK_USERNAME: GitHub Action
        SLACK_FOOTER: '\${{ github.workflow }}#\${{ github.run_number }}'
EOF

# Commit changes to github
print_message "Adding annotated version Tag and commeting:"
git status
git tag  -a -m "Begin Gitops with repo." 2.0.0-dev
git add .
git commit -m "Adding repo CI/CD capabilities using gitop and githubActions."
#git push --atomic https://${uname}:${secret}@github.com/Pixellot/${repo_name}.git master 2.0.0-dev

# Align github settings
print_message "Aligning Github repo with PIXELLOT settings:"
cd ../
git clone https://${uname}:${secret}@github.com/Pixellot/devops-il.git
cd devops-il/github-repo-align
export SECRET=${secret}
npm install
# npm run-script compile  ##############################3
# node out/align.js "${repo_name}" --align

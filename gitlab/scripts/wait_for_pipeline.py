#!/bin/python3

# Another example https://gitlab.com/inorton/gitlab-throttle

'''
wait-for-resources:
  stage: wait-for-resources
  image: oz123/koris-alpine:0.1.1
  script:
    - pip3 install python-gitlab
    - pip3 install -e .
    - python3 tests/scripts/wait_for_pipeline.py
'''

import os
import time

from urllib.parse import urlparse
import gitlab


from kolt.cloud.openstack import get_clients

_, _, cinder = get_clients()

URL = urlparse(os.getenv("CI_PROJECT_URL"))
gl = gitlab.Gitlab(URL.scheme + "://" + URL.hostname, private_token=os.getenv("ACCESS_TOKEN"))


project = gl.projects.get(os.getenv("CI_PROJECT_ID"))

def is_another_job_running():
    return sum([1 for lin in project.pipelines.list() if lin.attributes['status'] == 'running']) > 1  # noqa

while is_another_job_running() or cinder.volumes.list():
    print("Woha, another job is running, or there are some volumes left behined ...")
    print("In any case I'm waiting ... ")
    time.sleep(60)

print("Awesome !!! no jobs and no volume found!")
print("I will run that integration test now!")

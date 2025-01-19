# https://www.vladsiv.com/gitlab-parent-child-pipelines/
# service_generator.py
import sys

def generate_header():
    return f"""
stages:
  - build
  - test
  - deploy
"""

def generate_job(name):
    return f"""
build-{name}:
  stage: build
  script:
    - echo "Building service {name}"

test-{name}:
  stage: test
  needs:
    - build-{name}
  script:
    - echo "Testing service {name}"

deploy-{name}:
  stage: deploy
  needs:
    - build-{name}
    - test-{name}
  script:
    - echo "Deploying service {name}"
  when: manual
"""


def main(name):
    with open(f"service_{name}_pipeline.yml", "w") as f_out:
      f_out.write(generate_header())
      f_out.write(generate_job(name))


if __name__ == "__main__":
    name = sys.argv[1]
    main(name)

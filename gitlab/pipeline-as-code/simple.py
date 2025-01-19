# https://www.vladsiv.com/gitlab-parent-child-pipelines/
# child_generator.py
import sys


def generate_job(name):
    return f"""
test-{name}-job:
  script:
    - echo "Testing {name}"
"""


def main(names):
    with open("child_pipeline.yml", "w") as f_out:
        for name in names:
            f_out.write(generate_job(name))


if __name__ == "__main__":
    names = sys.argv[1].split(",")
    main(names)

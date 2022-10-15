#! python
from invoke import task
from glob import glob
import os
import json


@task
def test(c):
    print("Running jsonnet tests: ")
    test_results = []
    for root, sub_folders, files in os.walk("./tests"):
        for file in files:
            path = os.path.join(root, file)
            result = c.run("jsonnet --jpath ./components " + path, hide='both', warn='True')
            if result.ok:
                print('.')
                test_results.append(True)
            else:
                print(result.stderr)
                test_results.append(False)

    print_test_results(test_results)

def print_test_results(test_results):
    tests_successful = str(len([i for i in test_results if i]))
    tests_failed = str(len([i for i in test_results if not i]))
    print("Successful: " + tests_successful + " Failed: " + tests_failed + " Total : " + str(len(test_results)))


@task
def fmt(c):
    print("Formatting...")
    format_files(c, "./tests")
    format_files(c, "./components")
    print("Done.")


def format_files(c, files_path):
    for root, sub_folders, files in os.walk(files_path):
        for file in files:
            path = os.path.join(root, file)
            result = c.run("jsonnet fmt " + path, hide='stdout').stdout
            with open(path, "w+") as f:
                f.write(result)

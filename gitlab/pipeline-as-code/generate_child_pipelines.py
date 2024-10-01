import argparse
import shutil
import os
import yaml

from pathlib import Path


# ######################
# # Generate job details
# def generate_jobs_details(directory: str, search_file_name: str):
#     """Generate job details

#     Args:
#         directory: Base directory from which to search recursively
#         search_file_name: File name that indicates that the path containing it
#                           should have a pipeline.

#     Returns: List of objects with the fields `component`, `environment`, `region` and `instance`.
#     """

#     job_details_list = []
#     for root, dirs, files in os.walk(directory):
#         for file in files:
#             if file == search_file_name:
#                 file_path = os.path.relpath(root, start=directory)
#                 path_obj = Path(file_path)
#                 subdirs = [component for component in path_obj.parts if component != path_obj.root]
#                 job_details_list.append({
#                   "component": subdirs[0],
#                   "environment": subdirs[2],
#                   "region": subdirs[3],
#                   "instance": subdirs[4] if 4 < len(subdirs) else None
#                 })
#                 # found_paths.append(file_path)

#     for job_details in job_details_list:
#         print(job_details)

#     return job_details


######################
# Generate job details
def generate_jobs_details(directory: str, search_file_name: str):
    """Generate job details

    Args:
        directory: Base directory from which to search recursively
        search_file_name: File name that indicates that the path containing it
                          should have a pipeline.

    Returns: Object containing job details in a hierarchy of `component`, `environment`, `region` and `instance`
    """

    job_details = {}
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file == search_file_name:
                file_path = os.path.relpath(root, start=directory)
                path_obj = Path(file_path)
                subdirs = [component for component in path_obj.parts if component != path_obj.root]

                component = subdirs[0]
                environment = subdirs[2]
                region = subdirs[3]
                instance = subdirs[4] if 4 < len(subdirs) else None

                if component not in job_details:
                    job_details[component] = {}

                if environment not in job_details[component]:
                    job_details[component][environment] = {}

                if region not in job_details[component][environment]:
                    job_details[component][environment][region] = []

                if instance is not None:
                    job_details[component][environment][region].append(instance)

    return job_details


def generate_pipelines(output_directory: str, job_details: dict):
    data = {}
    data["include"] = []
    data["include"].append({
      "project": "HnBI/platform-as-a-service/common-resources/gitlab-ci-snippets",
      "ref": "master",
      "file": ["terragrunt-workflow/.gitlab-ci.yml"]
    })

    data["validate"] = {}
    data["validate"]["extends"] = []
    data["validate"]["extends"].append(".terragrunt-validate")
    data["validate"]["variables"] = {}
    data["validate"]["variables"]["ENV"] = "billing"

    data["plan"] = {}
    data["plan"]["extends"] = []
    data["plan"]["extends"].append(".terragrunt-plan")
    data["plan"]["needs"] = []
    data["plan"]["needs"].append("validate")


    # data = dict(
    #     A = 'a',
    #     B = dict(
    #         C = 'c',
    #         D = 'd',
    #         E = 'e',
    #     )
    # )

    with open('data.yml', 'w') as outfile:
        yaml.dump(data, outfile, default_flow_style=False)

    for component in job_details:
        print(component)
        for environment in job_details[component]:
            print(environment)

    # print("Hello")
    # print(output_directory)
    # print(job_details)



if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-d", "--directory", default=".", help="Root directory from which should scan for files to create pipelines.")
    parser.add_argument("-f", "--file-to-search", default="terragrunt.hcl", help="Name of the file to search to define when a child pipeline should be created")
    args = parser.parse_args()

    job_details = generate_jobs_details(args.directory, args.file_to_search)

    output_dir = f"{args.directory}/child_pipelines"
    if os.path.exists(output_dir):
        shutil.rmtree(output_dir)

    os.makedirs(output_dir)

    generate_pipelines(output_dir, job_details)

    # print(f"Component: {args.component}")

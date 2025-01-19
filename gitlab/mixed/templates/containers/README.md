# Containers

На этой странице:
  - [Общие положения](#общие-положения)
  - [`.containers.kaniko`](#containerskaniko)
  - [`.containers.trivy`](#containerstrivy)

## Общие положения

В данном разделе представлены шаблоны для работы с образами контейнеров.

Для их подключения необходимо в файле `.gitlab-ci.yml` проекта указать дополнительный [include](https://docs.gitlab.com/ce/ci/yaml/README.html#include) и добавить нужное расширения через [`extends`](https://docs.gitlab.com/ce/ci/yaml/README.html#extends) в конкретной задаче.

Пример:
```yml
# Подключаем данный проект
include:
  - project: "pub/ci"
    ref:     "0.0.5"
    file:    ".containers.gitlab-ci.yml"

stages:
  - build
  - test

# Собираем образ
"create image":
  extends: .containers.kaniko
  stage: build

# Проверяем на уязвимости
"test image":
  extends: .containers.trivy
  stage: test
  variables:
    TARGET_IMAGE: $CREATE_IMAGE
```

## `.containers.kaniko`

### Описание

Сборка образов контейнеров с помощью иснструмента [Kaniko](https://github.com/GoogleContainerTools/kaniko).

### Использование

```yml
"create image":
  extends: .containers.kaniko

"create second image":
  extends: .containers.kaniko
  variables:
    DOCKERFILE_PATH: second.dockerfile
    BUILD_CONTEXT: ./src/test
    BUILD_DST: |
      $CI_REGISTRY_IMAGE/some-image:$CI_COMMIT_SHORT_SHA
    BUILD_ARGS: |
      FOO=bar
      VAR=test
    BUILD_EXTRA_FLAGS: |
      --someFlag
      --andAnother
```

### Переменные

| Переменная              | По умолчанию                                       | Описание                                                                                                                                                                                                                                                                             |
| :---------------------- | -------------------------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`BUILD_ARGS`**        | `""`                                               | Аргументы сборки, передаваемые с флагом `--build-arg`.                                                                                                                                                                                                                               |
| **`BUILD_CACHE_REPO`**  | `$CI_REGISTRY_IMAGE/cache`                         | Registry репозиторий хранения кэша.                                                                                                                                                                                                                                                  |
| **`BUILD_CACHE`**       | `"true"`                                           | Использование кэширования сборки.                                                                                                                                                                                                                                                    |
| **`BUILD_CONTEXT`**     | `.`                                                | Путь от корня репозитория к директории сборки.                                                                                                                                                                                                                                       |
| **`BUILD_DST`**         | `$CI_REGISTRY_IMAGE/$REGISTRY_SUB_PATH:$IMAGE_TAG` | Многострочная переменная. Определяет путь деплоя образа.                                                                                                                                                                                                                             |
| **`BUILD_EXTRA_FLAGS`** | `""`                                               | Дополнительные аргументы для команды сборки.                                                                                                                                                                                                                                         |
| **`BUILD_TARGET`**      | `""`                                               | Флаг `--target` для сборки определённого этапа.                                                                                                                                                                                                                                      |
| **`DOCKERFILE_PATH`**   | `Dockerfile`                                       | Расположение Dockerfile относительно корня репозитория.                                                                                                                                                                                                                              |
| **`IMAGE_TAG`**         | `$CI_COMMIT_SHORT_SHA`                             | Тег образа. репозитория.                                                                                                                                                                                                                                                             |
| **`REGISTRY_SUB_PATH`** | `$CI_COMMIT_REF_SLUG`                              | По умолчанию путь к образу в Gitlab Registry состоит из имени домена реестра и пути к репозиторию (`registry.example.com/group/project`); данная переменная позволяет добавить к этому пути дополнительный подкаталог. Пример: `gitlab.example.com/group/project/$REGISTRY_SUB_PATH` |

### Примечания

После успешной сборки генерируется [dotenv артефакт](https://docs.gitlab.com/ce/ci/pipelines/job_artifacts.html#artifactsreportsdotenv) с указанием пути к образу и его SHA, доступный в последующих шагах пайплайна. Название переменной формируется из имени шага сбоки с заменой всех символов на `_` (нижнее подчёркивание) и переводом букв в верхний регистр. Так для шага `create image` переменная с образом будет `CREATE_IMAGE`.

## `.containers.trivy`

### Описание

Проверка образов контейнеров с помощью [Trivy](https://github.com/aquasecurity/trivy).

### Использование

```yml
"test image":
  extends: .containers.trivy
```

### Переменные

| Переменная              | По умолчанию                                       | Описание                                                                                                                                                                                                                                                                             |
| ----------------------- | -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **`TARGET_IMAGE`**      | `$CI_REGISTRY_IMAGE/$REGISTRY_SUB_PATH:$IMAGE_TAG` | Образ для проверки.                                                                                                                                                                                                                                                                  |
| **`IMAGE_TAG`**         | `$CI_COMMIT_SHORT_SHA`                             | Тег образа.                                                                                                                                                                                                                                                                          |
| **`REGISTRY_SUB_PATH`** | `$CI_COMMIT_REF_SLUG`                              | По умолчанию путь к образу в Gitlab Registry состоит из имени домена реестра и пути к репозиторию (`registry.example.com/group/project`); данная переменная позволяет добавить к этому пути дополнительный подкаталог. Пример: `gitlab.example.com/group/project/$REGISTRY_SUB_PATH` |

### Примечания

Также у Trivy есть свои переменные, которые можно посмотреть на [странице проекта](https://github.com/aquasecurity/trivy).

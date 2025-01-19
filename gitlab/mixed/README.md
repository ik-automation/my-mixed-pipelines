### Подключение
```yaml
#https://confluence.shops.com/display/ITDOC/Gitlab%3A+Common+pipeline
include:
  - project: 'pub/ci'
    ref: '0.0.5'
    file: '/.common.gitlab-ci.yml'

variables:
# https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/
  K8S_NAMESPACE: infra-tests
  SERVICE_NAME: example-go
# При наличии переменной SINGLE_DEPLOY, сервис на stage и develop будет раскатывать в единственном экземпляре
# SINGLE_DEPLOY: "true"
# Расположение файла для сборки docker образа
  DOCKERFILE_PATH: .o3/build/package/Dockerfile
#  В канал объявленый в переменной SLACK_DEPLOY_CHANNELS_DEV будут приходить оповещения о деплоях в development среду
#   SLACK_DEPLOY_CHANNELS_DEV:
#  В канал объявленый в переменной SLACK_DEPLOY_CHANNELS_STG будут приходить оповещения о деплоях в staging среду
#   SLACK_DEPLOY_CHANNELS_STG:
#  В канал объявленный в переменной SLACK_DEPLOY_CHANNELS_PROD будут приходить оповещения о деплоях на прод и release notes
#   SLACK_DEPLOY_CHANNELS_PROD:

# шаг для сборки проекта
build:
  image: golang:1.10
  stage: build
  tags: [build]
  script:
    - go build hello.go
  artifacts:
    paths:
      - hello
    expire_in: 1 day
# не убирайте except, иначе будет бессмысленный билд для тэгов
  except:
    - tags

create image:
# указание для шага со сборкой docker образа откуда брать артефакты
  dependencies:
    - build
```

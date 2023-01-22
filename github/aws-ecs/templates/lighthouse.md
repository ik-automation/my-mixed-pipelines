---
title: "{{ env.TITLE}}"
about: 'Are your scores flaky? You can run audits on Foo for stability and maintain a historical record!'
assignees: {{ env.ASSIGNEES}}
labels: performance
---

# Lighthouse Audit

| Accessibility            | Best Practices          |   Performance        | Progressive Web App          | SEO            |
|:------------------------:|:-----------------------:|:--------------------:|:----------------------------:|:--------------:|
| {{ env.ACCESSIBILITY }}  | {{ env.BEST_PRACTICES}} | {{ env.PERFORMANCE}} | {{ env.PROGRESSIVE_WEBAPP }} | {{ env.SEO }}  |

**Updated: {{ date | date('YYYY Do') }} of {{ date | date('MMMM') }}**

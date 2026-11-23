# Redmine Klassifikation

A small Redmine plugin that returns **only the value** of the custom field
`Klassifikation` for an issue or a project, so scripts and other tools can
read an item's data classification without parsing the full REST response.

Unclassified issues and projects **inherit** their classification from their
project and its parent projects.

## Requirements

- Redmine 5.0 or newer (tested with Redmine 6.1.6)
- A custom field named exactly `Klassifikation` for issues and/or projects
- REST API enabled (Administration → Settings → API) if you want to use API keys

## Installation

1. Copy the `redmine_klassifikation` folder into `<redmine>/plugins/`.
2. Restart Redmine.

No database migration is needed. Afterwards the plugin is listed under
Administration → Plugins.

## Setting up the custom field

The plugin does not create the field; create it yourself:

1. Administration → Custom fields → New custom field → **Issues** or **Projects**
   (you can create both, with the same name).
2. Name: `Klassifikation` (case-sensitive, must match exactly).
3. Format: **List**, with one value per line, for example:
   ```
   Öffentlich
   Intern
   Vertraulich
   Streng vertraulich
   ```
4. For an issue field, enable it for the relevant trackers and projects.

To use a different field name, change `FIELD_NAME` in
`app/controllers/klassifikation_controller.rb`.

## Usage

| Endpoint | Returns |
|---|---|
| `GET /issues/:id/klassifikation` | the issue's classification as plain text |
| `GET /issues/:id/klassifikation.json` | the same as JSON |
| `GET /projects/:id/klassifikation` | the project's classification as plain text (`:id` = identifier or numeric id) |
| `GET /projects/:id/klassifikation.json` | the same as JSON |

```bash
curl -H "X-Redmine-API-Key: <key>" https://<host>/redmine/issues/42/klassifikation
# Vertraulich

curl -H "X-Redmine-API-Key: <key>" https://<host>/redmine/issues/42/klassifikation.json
# {"klassifikation":"Intern","inherited_from":"myproject"}
```

- Plain text is the bare value with no trailing newline, or an empty body if
  no classification is set anywhere.
- JSON returns `klassifikation` (`null` if not set) and `inherited_from`: the
  identifier of the project the value came from, or `null` if it is the item's
  own value.
- The response format depends only on the URL extension (`.json`), not on
  the `Accept` header.

Authentication works with a logged-in browser session, the
`X-Redmine-API-Key` header, the `key` parameter, or HTTP Basic auth, like
Redmine's REST API.

## Inheritance

1. If the issue has its own value, that value is returned. It wins even if it
   is lower than the project's classification.
2. If the issue has no value (or the issue field is not enabled for it), the
   value of its project is used.
3. If the project has no value, its parent project is checked, then the
   grandparent, and so on up to the top-level project.
4. Projects follow the same rule: a subproject without a value inherits from
   its parent.

Example:

```
testprojekt         Intern
└─ sub              (none)               → Intern (from testprojekt)
   └─ subsub        Streng vertraulich   → Streng vertraulich
```

An issue without a value in `sub` returns `Intern`; one in `subsub` returns
`Streng vertraulich`.

## Permissions

The plugin follows Redmine's own visibility rules:

- The issue or project must be visible to the user.
- The field must be visible to the user's role (custom field setting
  "Visible").
- If the issue's own field is **hidden** from the user, the plugin returns
  `404` and does **not** fall back to the project. Otherwise a user could see
  a lower inherited classification than the one the issue really has.

## Status codes

| Code | Meaning |
|---|---|
| `200` | Success (the body may be empty if no classification is set) |
| `302` | Plain URL without valid credentials while Redmine requires login: redirect to the login page |
| `401` | `.json` URL without valid credentials (Redmine's normal REST API behaviour) |
| `404` | Issue/project not found or not visible, field hidden from the user, or no `Klassifikation` field exists for it |

`404` is also used for items the user cannot see, so the plugin does not
reveal whether they exist.

# BetaDrop Upload — Bitrise step

Upload the `.ipa` or `.apk` your workflow built to [BetaDrop](https://betadrop.app) and export the
install link as `$BETADROP_INSTALL_URL`.

```yaml
- git::https://github.com/betadrop-app/bitrise-step-betadrop.git@0.1.1:
    inputs:
      - api_token: $BETADROP_TOKEN
      - standing_link: acmebeta
      - inspect: "true"
```

Every input is described in `step.yml`. The step runs `@betadrop/cli`, so its behaviour matches the
[CLI reference](https://betadrop.app/docs/cli/).

## Testing locally

`tests/run.sh` runs the step against a stub `envman` and a CLI you point it at with
`BETADROP_CLI` — a local build of `betadrop-cli`, talking to a local API.

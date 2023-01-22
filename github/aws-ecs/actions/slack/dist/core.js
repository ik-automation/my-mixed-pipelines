"use strict";

const https = require('https');
// https://github.com/actions/toolkit/blob/main/packages/core/src/core.ts

/**
 * Gets the value of an input.
 * Unless trimWhitespace is set to false in InputOptions, the value is also trimmed.
 * Returns an empty string if the value is not defined.
 *
 * @param     name     name of the input to get
 * @param     options  optional. See InputOptions.
 * @returns   string
 */
function getInput(name, options) {
  const val = process.env[`INPUT_${name.replace(/ /g, '_').toUpperCase()}`] || ''
  if (options && options.required && !val) {
    throw new Error(`Input required and not supplied: ${name}`)
  }

  if (options && options.trimWhitespace === false) {
    return val
  }

  return val.trim()
}

function enrichMessage(input) {
  let { env, version, status, buildurl, rebuildurl, service, actor } = input;
  let buildUrl = `<${buildurl}|GithubAction Url :arrow_right:>`;
  let githubActionUrl = `<${rebuildurl}|ReBuild Url :arrow_right:>`;
  let actorUrl = `<https://github.com/${actor}|${actor.toUpperCase()} :arrow_right:>`;
  let st = '✅';
  let color = '#32a832';
  let emoji = ':white_check_mark:'
  if (status !== 'success') {
    st = '❌';
    color = '#eb4522';
    emoji = ':warning:'
  }
  return {
    "username": "Github Action Bot", // This will appear as user name who posts the message
    "text": `${st} Service "${service}" deployed "${status.toUpperCase()}".`,
    "icon_emoji": `${emoji}`, // User icon, you can also use custom icons here
    "mrkdwn_in": ["text", "value"],
    "attachments": [{
      "mrkdwn_in": ["text", "fields", "value", 'title'],
      "color": color, // color of the attachments sidebar.
      "title": `Env: ${env}. Version: ${version}.`,
      "fields": [
        {
          "title": "User",
          "value": actorUrl,
          "short": true
        },
      ]
    },
    {
      "color": color,
      "title": `Service "${service.toUpperCase()}".`,
    },
    {
      "blocks": [
        {
          "type": "section",
          "text": {
            "type": "mrkdwn",
            "text": "*Links*"
          }
        },
        {
          "type": "section",
          "text": {
            "type": "mrkdwn",
            "text": `${buildUrl}`
          }
        },
        {
          "type": "section",
          "text": {
            "type": "mrkdwn",
            "text": `${githubActionUrl}`
          }
        },
      ]
    }
    ]
  };
};

function failMessage(input) {
  let { buildurl, rebuildurl } = input;
  let buildUrl = `<${buildurl}|GithubAction Url :arrow_right:>`;
  let githubActionUrl = `<${rebuildurl}|ReBuild Url :arrow_right:>`;
  return {
    "username": "Github Action Bot", // This will appear as user name who posts the message
    "text": `Failed ❌.`, // text TODO should be Green or RED depends on status
    "icon_emoji": ":warning:", // User icon, you can also use custom icons here TODO should be Green or RED depends on status
  };
};

let sendSlackMessage = (opt) => {
  // console.log(JSON.stringify(messageBody, null, 2));
  let messageBody = JSON.stringify(opt.message);
  // Promisify the https.request
  return new Promise((resolve, reject) => {
    // general request options, we defined that it's a POST request and content is JSON
    const requestOptions = {
      method: 'POST',
      header: {
        'Content-Type': 'application/json'
      }
    };
    // actual request
    const req = https.request(opt.webhookUrl, requestOptions, (res) => {
      let response = '';
      res.on('data', d => response += d);
      // response finished, resolve the promise with data
      res.on('end', () => resolve(response) )
  });
  // there was an error, reject the promise
  req.on('error', (e) => reject(e));
  // send our message body (was parsed to JSON beforehand)
  req.write(messageBody);
  req.end();
});
}

module.exports = { getInput, enrichMessage, sendSlackMessage };

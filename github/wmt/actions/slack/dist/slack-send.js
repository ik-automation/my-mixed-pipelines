
const { getInput, enrichMessage, sendSlackMessage  } = require('./core');

module.exports = async function slackSend(core) {
  const webhookUrl = process.env.SLACK_WEBHOOK;
  if (webhookUrl === undefined) {
    throw new Error('Need to provide at least SLACK_WEBHOOK');
  }
  let payload = getInput('payload');
  console.log(payload);
  if (payload) {
    try {
      // confirm it is valid json
      payload = JSON.parse(payload);
    } catch (e) {
      // passed in payload wasn't valid json
      console.error('passed in payload was invalid JSON');
      throw new Error('Need to provide valid JSON payload');
    }
  }
  let message = enrichMessage(payload);
  // console.log(JSON.stringify(message));
  sendSlackMessage({ message, webhookUrl });
};

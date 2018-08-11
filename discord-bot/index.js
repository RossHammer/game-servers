const Discord = require('discord.js');
const winston = require('winston');
const AWS = require('aws-sdk');

const logger = winston.createLogger({
  level: 'debug',
  format: winston.format.combine(
    winston.format.colorize(),
    winston.format.timestamp(),
    winston.format.printf(info => `${info.timestamp} ${info.level}: ${info.message}`),
  ),
  transports: [
    new winston.transports.Console(),
  ],
});
const client = new Discord.Client();
const ec2 = new AWS.EC2({ region: 'us-west-2' });

const usage = 'How to use';

async function spotInstancesAreChanging() {
  const result = await ec2.describeSpotFleetRequests().promise();
  return result.SpotFleetRequestConfigs
    .some(r => ['pending_fulfillment', 'pending_termination'].includes(r.ActivityStatus)
      || ['submitted', 'cancelled_running', 'cancelled_terminating', 'modifying'].includes(r.SpotFleetRequestState));
}
async function getIp(name) {
  const result = await ec2.describeInstances({
    Filters: [
      { Name: 'tag:Name', Values: [name] },
      { Name: 'instance-state-name', Values: ['pending', 'running', 'shutting-down', 'stopping'] },
    ],
  }).promise();
  return [].concat(...result.Reservations.map(r => r.Instances)).map(i => i.PublicIpAddress)[0];
}

async function getAccount() {
  const result = await (new AWS.STS()).getCallerIdentity().promise();
  return result.Account;
}

async function startGame(name) {
  let templates;
  try {
    const result = await ec2.describeLaunchTemplates({ LaunchTemplateNames: [name] }).promise();
    templates = result.LaunchTemplates;
  } catch (error) {
    if (error.code === 'InvalidLaunchTemplateName.NotFoundException') {
      templates = [];
    } else {
      throw error;
    }
  }

  if (templates.length === 0) {
    return `Unknown game '${name}'`;
  }

  if (await spotInstancesAreChanging()) {
    return "The system's state is currently changing. Unable to launch game";
  }
  if (await getIp(name)) {
    return `${name} is already running at ${await getIp(name)}`;
  }

  winston.info(`Launching spot fleet for ${name}`);
  await ec2.requestSpotFleet({
    SpotFleetRequestConfig: {
      AllocationStrategy: 'lowestPrice',
      TargetCapacity: 1,
      IamFleetRole: `arn:aws:iam::${await getAccount()}:role/aws-ec2-spot-fleet-tagging-role`,
      TerminateInstancesWithExpiration: true,
      Type: 'request',
      LaunchTemplateConfigs: [
        {
          LaunchTemplateSpecification: {
            LaunchTemplateId: templates[0].LaunchTemplateId,
            Version: String(templates[0].LatestVersionNumber),
          },
        },
      ],
    },
  }).promise();

  return `${name} starting`;
}

client.on('ready', () => {
  logger.warn(`bot invite: https://discordapp.com/oauth2/authorize?client_id=${client.user.id}&scope=bot`);
});

client.on('message', async (message) => {
  if (message.mentions.users.has(client.user.id)) {
    const commands = message.content.replace(/<@.\d+>/, '').trim().toLowerCase().split(' ')
      .filter(i => i);
    if (commands.length !== 2) {
      await message.reply(usage);
      return;
    }
    const action = commands[0];
    const name = commands[1];
    logger.debug(`Trying to run action: '${action}' name: '${name}'`);

    let result;
    try {
      if (action === 'start') {
        result = await startGame(name);
      } else if (action === 'status') {
        result = `${name}: ${(await getIp(name)) || 'not running'}`;
      } else {
        result = usage;
      }
    } catch (error) {
      logger.error(error.message);
      result = `Unhandled error\n${error.message}`;
    }
    message.reply(result);
  }
});

let token;
if (process.env.BOT_TOKEN) {
  token = process.env.BOT_TOKEN;
}
if (process.argv.length === 3) {
  [, , token] = process.argv;
}

if (token) {
  client.login(token);
} else {
  logger.error('Missing bot token. Provided as only argument or BOT_TOKEN variable');
  process.exitCode = 1;
}

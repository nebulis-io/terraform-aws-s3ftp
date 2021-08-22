const aws = require("aws-sdk");

const ssm = new aws.SSM();

exports.handler = async (event, context) => {
  for (let record of event.Records) {
    if (
      record.s3.bucket.name === process.env.BUCKET_NAME &&
      record.s3.object.key === "login.txt"
    ) {
      console.log("Change of logins detected...");
      await ssm
        .sendCommand({
          DocumentName: process.env.SSM_GENERATE_LOGIN_DOCUMENT,
          InstanceIds: [process.env.S3FTP_INSTANCE_ID],
          DocumentVersion: "$LATEST",
        })
        .promise()
        .catch((err) => console.error(err));
    }
  }
};

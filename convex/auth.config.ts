import type { AuthConfig } from "convex/server";

const auth0Domain = process.env.AUTH0_DOMAIN!;
const auth0Audience = process.env.AUTH0_AUDIENCE!;

const authConfig = {
  providers: [
    {
      domain: auth0Domain,
      applicationID: auth0Audience,
    },
  ],
} satisfies AuthConfig;

export default authConfig;

import { internalQuery } from "./_generated/server";
import type { Id } from "./_generated/dataModel";
import { accessLevelForUser, type AccessLevel } from "./lib/access";
import { requireUser } from "./lib/auth";

export const authedUser = internalQuery({
  args: {},
  handler: async (
    ctx,
  ): Promise<{ userId: Id<"users">; access: AccessLevel }> => {
    const { user } = await requireUser(ctx);
    const access = await accessLevelForUser(ctx, user._id);
    return {
      userId: user._id,
      access,
    };
  },
});

module.exports = function (api) {
  api.cache(true);
  const isTest = process.env.JEST_WORKER_ID !== undefined;
  const plugins = isTest ? [] : ['react-native-reanimated/plugin'];

  return {
    presets: ['babel-preset-expo'],
    plugins,
  };
};

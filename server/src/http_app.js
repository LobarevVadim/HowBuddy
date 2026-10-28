import express from 'express';

// Express 4 does not forward rejected promises. Wrap each registered handler,
// including middleware, without changing Express's route matching or this binding.
export function createHttpApp({reportError = console.error, parseJson = true} = {}) {
  const app = express();
  const handleError = (error, _request, response, next) => {
    if (response.headersSent) return next(error);
    reportError(error);
    const invalidJson = error.type === 'entity.parse.failed';
    const tooLarge = error.type === 'entity.too.large';
    return response.status(invalidJson ? 400 : tooLarge ? 413 : 500).json({
      code: invalidJson ? 'invalid_json' : tooLarge ? 'payload_too_large' : 'internal_error',
      message: invalidJson ? 'Please send valid JSON.' : tooLarge ? 'This request is too large.' : 'Something went wrong. Please try again.',
    });
  };
  for (const method of ['get', 'post', 'put', 'patch', 'delete']) {
    const register = app[method].bind(app);
    app[method] = (path, ...handlers) => {
      // app.get(setting) remains a settings getter.
      if (!handlers.length) return register(path);
      return register(path, ...handlers.flat(Infinity).map((handler) => function (req, res, next) {
        try {
          Promise.resolve(handler.call(this, req, res, next)).catch((error) => handleError(error, req, res, next));
        } catch (error) {
          handleError(error, req, res, next);
        }
      }));
    };
  }
  // An error handler ahead of routes catches parser errors; route promise errors
  // are sent through the same function by the wrapper above.
  app.locals.handleError = handleError;
  if (parseJson) app.use(express.json({limit: '1mb'}));
  app.use(handleError);
  return app;
}

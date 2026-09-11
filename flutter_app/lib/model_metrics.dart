class ModelMetrics {
  static const data = {
    'Simple Linear Regression': {
      'r2': 0.7099,
      'mae': 0.5294,
      'rmse': 0.6635,
      'mse': 0.4403,
      'mape': 10.42,
    },
    'Multiple Linear Regression': {
      'r2': 0.7100,
      'mae': 0.5292,
      'rmse': 0.6635,
      'mse': 0.4402,
      'mape': 10.42,
    },
    'Polynomial Regression (d=2)': {
      'r2': 0.7102,
      'mae': 0.5279,
      'rmse': 0.6637,
      'mse': 0.4405,
      'mape': 10.39,
    },
  };
  static const best = 'Polynomial Regression (d=2)';
  static const samples = 1292;
  static const training = 1034;
  static const testing = 258;
  static const distribution = {'Small': 262, 'Medium': 694, 'Large': 336};

  static const simpleCoefWeight = 0.4569;
  static const simpleIntercept = -0.6080;

  static const multipleCoefWeight = 0.4580;
  static const multipleCoefSize = -0.0053;
  static const multipleIntercept = -0.6108;

  static const polyFeatNames = [
    'Weight',
    'Size',
    'Weight^2',
    'Weight Size',
    'Size^2',
  ];
  static const polyCoefs = [0.435680, 0.086517, -0.003075, 0.047385, -0.164087];
  static const polyIntercept = -0.5480;
}

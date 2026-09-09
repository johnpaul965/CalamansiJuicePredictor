class ModelMetrics {
  static const data = {
    'Simple Linear Regression': {'mae': 0.5120, 'r2': 0.8033},
    'Multiple Linear Regression': {'mae': 0.5380, 'r2': 0.7900},
    'Polynomial Regression (d=2)': {'mae': 0.5823, 'r2': 0.7547},
  };
  static const best = 'Simple Linear Regression';
  static const samples = 1292;
  static const training = 1033;
  static const testing = 259;
  static const distribution = {'Small': 265, 'Medium': 694, 'Large': 333};

  static const simpleCoefWeight = 0.4022;
  static const simpleIntercept = 0.0917;

  static const multipleCoefWeight = 0.3058;
  static const multipleCoefSize = 0.4745;
  static const multipleIntercept = 0.3224;

  static const polyFeatNames = [
    'Weight',
    'Size',
    'Weight^2',
    'Weight Size',
    'Size^2',
  ];
  static const polyCoefs = [-1.381236, 7.428875, 0.183833, -1.416874, 2.611992];
  static const polyIntercept = 3.5026;
}

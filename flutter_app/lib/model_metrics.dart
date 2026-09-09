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
}

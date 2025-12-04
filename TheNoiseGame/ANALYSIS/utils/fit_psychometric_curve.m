function [fit_params, fitted_curve, gof] = fit_psychometric_curve(x_data, y_data, curve_type)
% FIT_PSYCHOMETRIC_CURVE Fit psychometric function to behavioral data
%
% Inputs:
%   x_data - Independent variable (e.g., contrast levels)
%   y_data - Dependent variable (e.g., proportion correct)
%   curve_type - 'sigmoid' (default) or 'weibull'
%
% Outputs:
%   fit_params - Structure with fitted parameters
%   fitted_curve - Function handle for the fitted curve
%   gof - Goodness of fit metrics (R-squared, RMSE)

    if nargin < 3
        curve_type = 'sigmoid';
    end
    
    % Remove NaN values
    valid_idx = ~isnan(x_data) & ~isnan(y_data);
    x_data = x_data(valid_idx);
    y_data = y_data(valid_idx);
    
    if length(x_data) < 3
        warning('Insufficient data points for curve fitting');
        fit_params = struct();
        fitted_curve = @(x) nan(size(x));
        gof = struct('rsquared', NaN, 'rmse', NaN);
        return;
    end
    
    switch lower(curve_type)
        case 'sigmoid'
            % 4-parameter sigmoid: y = lapse + (1-lapse-guess)/(1+exp(-(x-threshold)/slope))
            sigmoid_fun = @(p, x) p(3) + (1 - p(3) - p(4)) ./ (1 + exp(-(x - p(1)) ./ p(2)));
            
            % Initial parameter guesses
            % p(1) = threshold (midpoint), p(2) = slope, p(3) = guess rate, p(4) = lapse rate
            threshold_init = median(x_data);
            slope_init = (max(x_data) - min(x_data)) / 4;
            guess_init = 0.0;  % No guess rate for detection tasks
            lapse_init = 0.05; % Small lapse rate
            
            p0 = [threshold_init, slope_init, guess_init, lapse_init];
            
            % Parameter bounds
            lb = [min(x_data), 0.001, 0, 0];
            ub = [max(x_data), max(x_data), 0.2, 0.2];
            
            try
                % Fit using lsqcurvefit (more stable than nlinfit for constrained fitting)
                options = optimoptions('lsqcurvefit', 'Display', 'off');
                p_fit = lsqcurvefit(sigmoid_fun, p0, x_data, y_data, lb, ub, options);
                
                fit_params.threshold = p_fit(1);
                fit_params.slope = p_fit(2);
                fit_params.guess_rate = p_fit(3);
                fit_params.lapse_rate = p_fit(4);
                fitted_curve = @(x) sigmoid_fun(p_fit, x);
            catch
                warning('Curve fitting failed, returning NaN parameters');
                fit_params = struct('threshold', NaN, 'slope', NaN, 'guess_rate', NaN, 'lapse_rate', NaN);
                fitted_curve = @(x) nan(size(x));
            end
            
        case 'weibull'
            % Weibull function: y = 1 - (1-lapse)*exp(-(x/alpha)^beta)
            weibull_fun = @(p, x) 1 - (1 - p(3)) .* exp(-(x ./ p(1)).^p(2));
            
            % Initial guesses
            alpha_init = median(x_data);
            beta_init = 2;
            lapse_init = 0.05;
            
            p0 = [alpha_init, beta_init, lapse_init];
            lb = [min(x_data), 0.5, 0];
            ub = [max(x_data), 10, 0.2];
            
            try
                options = optimoptions('lsqcurvefit', 'Display', 'off');
                p_fit = lsqcurvefit(weibull_fun, p0, x_data, y_data, lb, ub, options);
                
                fit_params.alpha = p_fit(1);
                fit_params.beta = p_fit(2);
                fit_params.lapse_rate = p_fit(3);
                fitted_curve = @(x) weibull_fun(p_fit, x);
            catch
                warning('Curve fitting failed, returning NaN parameters');
                fit_params = struct('alpha', NaN, 'beta', NaN, 'lapse_rate', NaN);
                fitted_curve = @(x) nan(size(x));
            end
            
        otherwise
            error('Unknown curve type: %s', curve_type);
    end
    
    % Calculate goodness of fit
    try
        field_names = fieldnames(fit_params);
        if ~isempty(field_names) && ~isnan(fit_params.(field_names{1}))
            y_pred = fitted_curve(x_data);
            ss_res = sum((y_data - y_pred).^2);
            ss_tot = sum((y_data - mean(y_data)).^2);
            
            gof.rsquared = 1 - ss_res / ss_tot;
            gof.rmse = sqrt(mean((y_data - y_pred).^2));
        else
            gof.rsquared = NaN;
            gof.rmse = NaN;
        end
    catch
        gof.rsquared = NaN;
        gof.rmse = NaN;
    end
end


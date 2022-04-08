function out = deduce_wall_thickness(im_input, centroid, varargin)
% Find lv and associated metrics in an image

p = inputParser;
addRequired(p, 'im_input');
addRequired(p, 'centroid');
addOptional(p, 'rotation_angles', 0:10:350);
addOptional(p, 'interp_points', 1000);
addOptional(p, 'min_prominence', 0.2);
addOptional(p, 'rel_height', 0.95);
addOptional(p, 'max_radius', 20);
addOptional(p, 'max_wall_thickness', 15);
addOptional(p, 'figure_working', 4);
addOptional(p, 'figure_summary', 5);
addOptional(p, 'figure_summary_file_string', '');
addOptional(p, 'figure_output_types', {'png'});
addOptional(p, 'figure_summary_title', '');
parse(p, im_input, centroid, varargin{:});

p = p.Results;

% Code

% % Deduce image size
[y_pixels, x_pixels] = size(im_input);

% Median filtered
im_median_filtered = medfilt2(im_input);

% Contrast stretched
im_stretched = imadjust(im_median_filtered);

% Set up figure if requred
if (~isempty(p.figure_working))
    fig_rows = 2;
    fig_cols = 4;
    figure(p.figure_working);
    clf;
    colormap(gray);

    sp_counter = 1;
    subplot(fig_rows, fig_cols, sp_counter);
    imagesc(im_input);
    title('Input image');

    sp_counter = sp_counter + 1;
    subplot(fig_rows, fig_cols, sp_counter);
    cla;
    hold on;
    imagesc(im_median_filtered);
    xlim([1 x_pixels]);
    ylim([1 y_pixels]);
    set(gca, 'YDir', 'reverse');
    title('Median filtered');
    
    sp_counter = sp_counter + 1;
    subplot(fig_rows, fig_cols, sp_counter);
    cla;
    hold on;
    imagesc(im_stretched);
    xlim([1 x_pixels]);
    ylim([1 y_pixels]);
    set(gca, 'YDir', 'reverse');
    title('Contrast enhanced');
    colorbar
end

% Rotate image to work out profile
sp_holder = sp_counter;

% Initialise
out.rotation_angles = p.rotation_angles';
out.inner_radius = NaN * ones(numel(p.rotation_angles), 1);
out.outer_radius = out.inner_radius;
out.septal_thickness_mean = NaN;
out.septal_thickness_n = NaN;
out.septal_thickness_sem = NaN;

for rot_counter = 1 : numel(p.rotation_angles)

    im_working = im_input;
    
    % Rotate the image
    im_rot = rotateAround(im_working, ...
                centroid(2), centroid(1), ...
                p.rotation_angles(rot_counter), ...
                'bicubic');
    
    % Normalize
    im_rot = double(im_rot);
    im_rot = im_rot - min(im_rot(:));
    im_rot = im_rot ./ max(im_rot(:));
            
    % Pull profile
    x = 1 : round(centroid(2));
    y = double(im_rot(x, round(centroid(1))));
    x_int = linspace(1, x(end), p.interp_points);
    y_int = interp1(x, y, x_int);
    
    % Find peaks
    [pks, locs] = findpeaks(-y_int, ...
                    'MinPeakProminence', p.min_prominence);
    xp = x_int(locs);
    yp = y_int(locs);
    
    vi_inner = [];
    vi_outer = [];
    
    if ((~isempty(locs)) & ((numel(x) - xp(end)) < p.max_radius))

        % Look for the inner wall
        vi_inner = find( ...
            (x_int > x_int(locs(end))) & ...
            (y_int > (y_int(locs(end)) + (p.rel_height * p.min_prominence))), ...
            1, 'first');
        
        if (~isempty(vi_inner))
            out.inner_radius(rot_counter) = ...
                x_int(end) - x_int(vi_inner);
            
            % Look for outer wall
            vi_outer = find( ...
                (x_int < x_int(vi_inner)) & ...
                (y_int > (y_int(locs(end)) + ...
                            (p.rel_height * p.min_prominence))), ...
                1, 'last');
            
            if (~isempty(vi_outer))
                out.outer_radius(rot_counter) = ...
                    x_int(end) - x_int(vi_outer);
            end
        end
    end
    
    subplot(fig_rows, fig_cols, sp_holder + 1);
    cla
    hold on;
    imagesc(im_rot);
    plot(centroid(1), centroid(2), 'r+');
    plot(centroid(1), centroid(2), 'co');
    xlim([1 x_pixels]);
    ylim([1 y_pixels]);
    set(gca, 'YDir', 'reverse');
    title(sprintf('Rotated by %.0f', p.rotation_angles(rot_counter)));
    
    subplot(fig_rows, fig_cols, sp_holder + 2);
    cla
    hold on;
    plot(x_int, y_int, 'c-');
    plot(x_int(locs), y_int(locs), 'gs');
    if (~isempty(vi_inner))
        plot(x_int(vi_inner), y_int(vi_inner), 'ro');
    end
    if (~isempty(vi_outer))
        plot(x_int(vi_outer), y_int(vi_outer), 'mo');
    end
end

% Filter
est_thickness = out.outer_radius - out.inner_radius;
vi_valid_thickness = find(est_thickness < p.max_wall_thickness);
test_inner_radii = out.inner_radius(vi_valid_thickness);
out.valid_radii = vi_valid_thickness(~isoutlier(test_inner_radii));

temp_angles = out.rotation_angles(out.valid_radii);
temp_inner_radius = out.inner_radius(out.valid_radii);
temp_outer_radius = out.outer_radius(out.valid_radii);
diff_angles = diff(out.rotation_angles(out.valid_radii));

[a,a_run] = RunLength_M(diff_angles);
if (isempty(a))
    return
end
% Cope with wrap-around
if (a(1) == a(end))
    % Is the septum wrapping around
    if ((temp_angles(end) - temp_angles(1)) == out.rotation_angles(end))
        a_run(end) = a_run(end) + a_run(1);
        temp_angles = [temp_angles ; temp_angles];
        temp_inner_radius = [temp_inner_radius ; temp_inner_radius];
        temp_outer_radius = [temp_outer_radius ; temp_outer_radius];
    end
end

[max_run, max_ind] = max(a_run)
if (max_run >= 2)

    run_start_ind = sum(a_run(1:max_ind-1))+1;
    out.septal_ind = run_start_ind + [0 : max_run];
    out.septal_angles = temp_angles(out.septal_ind);
    out.septal_inner_radius = temp_inner_radius(out.septal_ind);
    out.septal_outer_radius = temp_outer_radius(out.septal_ind);

    out.septal_inner_x = centroid(1) + out.septal_inner_radius .* ...
                    sind(out.septal_angles);
    out.septal_inner_y = centroid(2) - out.septal_inner_radius .* ...
                    cosd(out.septal_angles);
    out.septal_outer_x = centroid(1) + out.septal_outer_radius .* ...
                    sind(out.septal_angles);
    out.septal_outer_y = centroid(2) - out.septal_outer_radius .* ...
                    cosd(out.septal_angles);

    out.h = hypot([out.septal_outer_x - out.septal_inner_x], ...
                [out.septal_outer_y - out.septal_inner_y]);
    stats = summary_stats(out.h);
    out.septal_thickness_mean = stats.mean;
    out.septal_thickness_n = stats.n;
    out.septal_thickness_sem = stats.sem;
end
           
            
if (~isempty(p.figure_working))

    sp_counter = sp_counter + 3;
    subplot(fig_rows, fig_cols, sp_counter);
    cla;
    hold on;
    imagesc(im_working);
    plot(centroid(1), centroid(2), 'r+');
    plot(centroid(1) + out.inner_radius' .* sind(p.rotation_angles), ...
        centroid(2) - out.inner_radius' .* cosd(p.rotation_angles), 'ro');
    plot(centroid(1) + out.outer_radius' .* sind(p.rotation_angles), ...
        centroid(2) - out.outer_radius' .* cosd(p.rotation_angles), 'md');
    
    xlim([1+50 x_pixels-50]);
    ylim([1+50 y_pixels-50]);
    set(gca, 'YDir', 'reverse');

    sp_counter = sp_counter + 1;
    subplot(fig_rows, fig_cols, sp_counter);
    cla;
    hold on;
    imagesc(im_working);
    plot(centroid(1), centroid(2), 'r+');
    if (isfield(out, 'septal_inner_x'))
        plot(out.septal_inner_x, out.septal_inner_y, 'ro');
        plot(out.septal_outer_x, out.septal_outer_y, 'md');
    end

    xlim([1+50 x_pixels-50]);
    ylim([1+50 y_pixels-50]);
    set(gca, 'YDir', 'reverse');
end

if (~isempty(p.figure_summary))
    sp = initialise_publication_quality_figure( ...
            'figure_handle', p.figure_summary, ...
            'no_of_panels_high', 1, ...
            'no_of_panels_wide', 1, ...
            'right_margin', 4.5, ...
            'axes_padding_bottom', 0.5, ...
            'top_margin', 0.5, ...
            'bottom_margin', 0, ...
            'panel_label_font_size', 0);

    imagesc(im_input);
    colormap(gray);
    hold on;
    plot(centroid(1), centroid(2), 'y+');
    plot(centroid(1), centroid(2), 'co');
    
    if (isfield(out, 'septal_inner_x'))
        plot(out.septal_inner_x, out.septal_inner_y, 'ro');
        plot(out.septal_outer_x, out.septal_outer_y, 'md');
        plot([out.septal_inner_x out.septal_outer_x]', ...
            [out.septal_inner_y out.septal_outer_y]', 'g-');
    end

    z = 50;
    xlim([1+z x_pixels-z]);
    ylim([1+z y_pixels-z]);
    set(gca, 'YDir', 'reverse');
    
    title(sprintf('%s\nSeptal thickness: %.2f', ...
        p.figure_summary_title, ...
        out.septal_thickness_mean));
    
    if (~isempty(p.figure_summary_file_string))
        for i = 1 : numel(p.figure_output_types)
            figure_export( ...
                'output_file_string', p.figure_summary_file_string, ...
                'output_type', p.figure_output_types{i});
        end
    end
end




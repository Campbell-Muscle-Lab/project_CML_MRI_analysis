function out = identify_lv(im_input, varargin)
% Find lv and associated metrics in an image

p = inputParser;
addRequired(p, 'im_input');
addOptional(p, 'idx_crop', [66 136]);
addOptional(p, 'contrast_range', [0.3 1]);
addOptional(p, 'circle_expansion_factor', 2);
addOptional(p, 'hmin', 1);
addOptional(p, 'min_ventricular_area', 100);
addOptional(p, 'prop_fields', {'Area','Centroid','Eccentricity','Solidity'});
addOptional(p, 'figure_working', 2);
addOptional(p, 'figure_summary', 3);
addOptional(p, 'figure_summary_file_string', '');
addOptional(p, 'figure_output_types', {'png'});
addOptional(p, 'figure_summary_title', '');
parse(p, im_input, varargin{:});

p = p.Results;

% Code

% % Deduce image size
[y_pixels, x_pixels] = size(im_input);

% Contrast enhance
im_median_filtered = medfilt2(im_input);

% Contrast stretched
im_stretched = imadjust(im_median_filtered);

% Crop image
im_crop = im_stretched;
px = 1:x_pixels;
im_crop(:,(px < p.idx_crop(1)) | (px > p.idx_crop(2))) = 0;
py = 1:y_pixels;
im_crop(((py < p.idx_crop(1)) | (py > p.idx_crop(2))),:) = 0;


if (~isempty(p.figure_summary))
    sp = initialise_publication_quality_figure( ...
            'figure_handle', p.figure_summary, ...
            'no_of_panels_high', 1, ...
            'no_of_panels_wide', 1, ...
            'right_margin', 4.5, ...
            'axes_padding_bottom', 0.5, ...
            'bottom_margin', 0, ...
            'panel_label_font_size', 0);
    
    imagesc(im_input);
    hold on;
    
    xlim([1 x_pixels]);
    ylim([1 y_pixels]);
    set(gca, 'YDir', 'reverse');

end
    
% Find circles
[centers, radii] = imfindcircles(im_crop, ...
                        round(sqrt(p.min_ventricular_area/pi)) * [1 100], ...
                        'ObjectPolarity', 'bright');
                                
% Break out if no circles
if (isempty(centers))
    out = [];
    if (~isempty(p.figure_summary))
        figure(p.figure_summary);
        title(sprintf('%s No circles detected', p.figure_summary_title), ...
            'Interpreter', 'none');
        save_summary_file();
    end
    return
end

% Create masks for the largest circle, and an enlarged version
im_circle = zeros(size(im_input), 'logical');
im_mask = zeros(size(im_input));

for r = 1 : size(im_circle, 2)
    for c = 1 : size(im_circle, 1)
        h = hypot(r - centers(1,2), c - centers(1,1));
        if (h < radii(1))
            im_circle(r,c) = 1;
        end
        if (h < p.circle_expansion_factor * radii(1))
            im_mask(r,c) = 1;
        end
    end
end

% Binarize
im_bin = imbinarize(im_stretched ,'adaptive');

% Masked
im_bin_masked = im_bin;
im_bin_masked(~im_mask) = 0;
im_bin_masked = imfill(im_bin_masked, 'holes');

% Remove small objects
im_tidied = bwareafilt(im_bin_masked, [p.min_ventricular_area inf]);

% Watershed
im_distance = -bwdist(~im_tidied);

% Flatten distance
im_flattened = im_distance;
im_flattened(im_flattened < -p.hmin) = -p.hmin;

% Watershed
im_watershed = watershed(im_flattened, 4);
im_watershed(~im_tidied) = 0;

% Find the most circular that meets the min size criteria
s = regionprops(im_watershed, p.prop_fields);
areas = cat(1, s.Area);
eccentricities = cat(1, s.Eccentricity);

vi = find(areas >= p.min_ventricular_area);
% Break out if watershed labels do not meet area criteria
if (isempty(vi))
    if (~isempty(p.figure_summary))
        figure(p.figure_summary);
        title(sprintf('%s watershed areas too small', p.figure_summary_title), ...
            'Interpreter', 'none');
        save_summary_file();
    end
    
    out = [];
    return
end
[~, vi2] = min(eccentricities(vi));
lv_ind = vi(vi2);

% Set up the im_lv_mask
im_lv_mask = zeros(size(im_watershed));
im_lv_mask(im_watershed==lv_ind) = 1;

% Save the output information
for i = 1 : numel(p.prop_fields)
    temp = cat(1, s.(p.prop_fields{i}));
    temp = temp(lv_ind,:);
    if (numel(temp)==1)
        out.(p.prop_fields{i}) = temp;
    else
        for j = 1:numel(temp)
            f_string = sprintf('%s_%i', p.prop_fields{i}, j);
            out.(f_string) = temp(j);
        end
    end
end

% Set up figure if requred
if (~isempty(p.figure_working))
    fig_rows = 3;
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
    % Find the boundary of the circle
    circle_boundary = bwboundaries(im_circle);
    circle_boundary = circle_boundary{1};
    plot(circle_boundary(:,2), circle_boundary(:,1), 'b-', 'LineWidth', 2);
    plot([p.idx_crop(1) p.idx_crop(1) p.idx_crop(2) p.idx_crop(2) p.idx_crop(1)], ...
        [p.idx_crop(1) p.idx_crop(2) p.idx_crop(2) p.idx_crop(1) p.idx_crop(1)], 'y-');
    xlim([1 x_pixels]);
    ylim([1 y_pixels]);
    set(gca, 'YDir', 'reverse');
    title('Contrast enhanced');
    
    sp_counter = sp_counter + 1;
    subplot(fig_rows, fig_cols, sp_counter);
    cla
    hold on;
    imagesc(im_stretched);
    im_g = zeros([size(im_circle) 3]);
    im_g(:,:,2) = 1;
    h = image(im_g);
    set(h, 'AlphaData', 0.2 * im_mask);
    xlim([1 x_pixels]);
    ylim([1 y_pixels]);
    set(gca, 'YDir', 'reverse');
    title('Ventricle mask');

    sp_counter = sp_counter + 1;
    subplot(fig_rows, fig_cols, sp_counter);
    cla
    hold on;
    imagesc(im_bin);
    xlim([1 x_pixels]);
    ylim([1 y_pixels]);
    set(gca, 'YDir', 'reverse');
    title('Binarized');

    sp_counter = sp_counter + 1;
    subplot(fig_rows, fig_cols, sp_counter);
    cla
    hold on;
    imagesc(im_bin_masked);
    xlim([1 x_pixels]);
    ylim([1 y_pixels]);
    set(gca, 'YDir', 'reverse');
    title('Binarized and masked');
    
    sp_counter = sp_counter + 1;
    subplot(fig_rows, fig_cols, sp_counter);
    cla
    hold on;
    imagesc(im_tidied);
    xlim([1 x_pixels]);
    ylim([1 y_pixels]);
    set(gca, 'YDir', 'reverse');
    title('Tidied');    
    
    sp_counter = sp_counter + 1;
    subplot(fig_rows, fig_cols, sp_counter);
    cla
    hold on;
    imagesc(im_distance);
    xlim([1 x_pixels]);
    ylim([1 y_pixels]);
    set(gca, 'YDir', 'reverse');
    title('Distance');
    colorbar;

    sp_counter = sp_counter + 1;
    subplot(fig_rows, fig_cols, sp_counter);
    cla
    hold on;
    imagesc(im_flattened);
    xlim([1 x_pixels]);
    ylim([1 y_pixels]);
    set(gca, 'YDir', 'reverse');
    title('Flattened');
    colorbar;
    
    sp_counter = sp_counter + 1;
    subplot(fig_rows, fig_cols, sp_counter);
    cla
    hold on;
    imagesc(im_watershed);
    xlim([1 x_pixels]);
    ylim([1 y_pixels]);
    set(gca, 'YDir', 'reverse');
    title('Watershed');

    sp_counter = sp_counter + 1;
    subplot(fig_rows, fig_cols, sp_counter);
    cla
    hold on;
    imagesc(im_watershed);
    plot(out.Centroid_1, out.Centroid_2, 'w+');
    plot(out.Centroid_1, out.Centroid_2, 'mo');
    xlim([1 x_pixels]);
    ylim([1 y_pixels]);
    set(gca, 'YDir', 'reverse');
    title('LV candidate');
    
end

if (~isempty(p.figure_summary))
 
    figure(p.figure_summary);
    hold on;
    colormap(gray);
    im_g = zeros([size(im_input) 3]);
    im_g(:,:,2) = 1;
    h = image(im_g);
    set(h, 'AlphaData', 0.2 * im_lv_mask);
    
    plot(out.Centroid_1, out.Centroid_2, 'y+');
    plot(out.Centroid_1, out.Centroid_2, 'co');
        
    xlim([1 x_pixels]);
    ylim([1 y_pixels]);
    set(gca, 'YDir', 'reverse');
    title(p.figure_summary_title, 'Interpreter', 'none');
    
    drawnow;
    
    % Save summary_file
    save_summary_file();
end

    function save_summary_file()
        if (~isempty(p.figure_summary_file_string))
            % Save figure to file
            sprintf('Saving to %s', p.figure_summary_file_string);
            for i = 1 : numel(p.figure_output_types)
                figure_export('output_file_string', ...
                                    p.figure_summary_file_string, ...
                            'output_type', p.figure_output_types{i});
            end
        end
    end
end





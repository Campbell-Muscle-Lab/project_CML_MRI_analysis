function deduce_ed_frame

% Variables
dfs = '../data/manual_check/a.xlsx';
p_order = 4;

output_file_string = '../output/ed_frame.xlsx';

% Code
d = readtable(dfs);
dn = d.Properties.VariableNames';

uc = unique(d.deid_code);

figure(1);
clf;

for i = 1 : numel(uc)
    
    vi = find(strcmp(d.deid_code, uc{i}));
    d2 = d(vi,:);
    
    x = d2.frame_number;
    y = d2.Area;
    
    cla
    hold on;
    plot(x,y,'bo');
    
    
    p = polyfit(x,y, p_order);
    py = polyval(p, x);
    
    x_int = linspace(x(1), x(end), 100);
    y_int = interp1(x, py, x_int, 'spline');
    plot(x_int, y_int, 'r-');
    
    r_squared = calculate_r_squared(y, py);
    
    title(sprintf('%s r^2=%.3f', uc{i}, r_squared));
    
    [~, max_ind] = max(y);
    
    out.code{i} = uc{i};
    out.r_squared(i) = r_squared;
    out.ed_frame(i) = max_ind;
    
    drawnow;
%     pause(1);
end

try
    delete(output_file_string);
end
out = columnize_structure(out);
out = struct2table(out);
writetable(out, output_file_string);

    
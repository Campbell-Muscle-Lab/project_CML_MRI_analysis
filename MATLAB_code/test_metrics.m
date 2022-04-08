function test_metrics

data_file_string = '../data/manual_check/a.xlsx';
output_frame_file_string = '../data/manual_check/output_frames.xlsx';

d = readtable(data_file_string);
dn = d.Properties.VariableNames'

cm = [1 0 0 ; 0 0 1];
% 
% figure(1);
% clf
% 
% for i = 1 : 2
%     subplot(2,1,1);
%     
%     vi = find(d.Centroid_identified == (i-1));
%     plot3(d.Area(vi), d.Eccentricity(vi), d.Solidity(vi), 'o', 'Color', cm(i,:));
%     hold on;
%     
%     subplot(2,1,2);
%         
%     vi = find(d.LV_identified == (i-1));
%     plot3(d.Area(vi), d.Eccentricity(vi), d.Solidity(vi), 'o', 'Color', cm(i,:));
%     hold on
% end

% d = d(~isnan(d.Centroid_identified),:);
d = d(d.LV_identified==1, :);

gi = [];

figure(1);
clf
hold on;
uc = unique(d.deid_code);
nu = numel(uc)

out = []
counter = 1

for i = 1 : numel(uc)
    vi = find(strcmp(d.deid_code, uc{i}));
    d2 = d(vi,:);
    plot(d2.frame_number, d2.Area, 'b-');
    
    [~, max_ind] = max(d2.Area);
    
    if ((max_ind >= 6) & (max_ind <= 11))
        out.deid_code{counter} = uc{i};
        out.ed_frame(counter) = max_ind;
        counter = counter + 1;
    end
end

out = columnize_structure(out);
out = struct2table(out);

try
    delete(output_frame_file_string);
end
writetable(out, output_frame_file_string);

# Data folder

Place local datasets and target spreadsheets here. The `.gitignore` excludes MAT and Excel data files by default.

A grouped LEAPD dataset should provide:

```matlab
EEG
Filenames
ChannelLocations
```

with:

```matlab
EEG{channel}{1} = group 1 / class 1 subjects
EEG{channel}{2} = group 0 / class 0 subjects

Filenames{1} = group 1 subject IDs
Filenames{2} = group 0 subject IDs
```

A correlation test dataset may contain only the target group. See the repository README for accepted layouts.

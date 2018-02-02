# HumbleBundleDL

HumbleBundle is a great way to support charities and get some cool books/games in the process. My only issue is that there isn't a native way to bulk-download the files in the bundle. Initially I was using a javascript snippet that would generate a list of wget commands but then the site changed, invalidating the code. After poking around some I found that a couple of simple API calls would give me everything I needed to get the files, thus this script was born. It's still very rough but it's coming along as I take the time to work on it.

Contributions very much welcome.

## TODO
* Ask to set a download path, save in the .humblebundle.cfg file
* Get the sessionID cookie via an API call instead of logging in via a browser and logging in manually
* Put more work in to cleaning up the file names, maybe make it optional for those that don't care about spaces/etc in the filenames
* Ask if the directory name created is fine, let the user edit it
* Check for existing files, validate the MD5 and skip if file exists
* Make the script portable between OS types? Not important to me exactly, but I'm sure someone else would like it

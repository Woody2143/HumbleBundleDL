# HumbleBundleDL

HumbleBundle is a great way to support charities and get some cool books/games in the process. My only issue is that there isn't a native way to bulk-download the files in the bundle. Initially I was using a javascript snippet that would generate a list of wget commands but then the site changed, invalidating the code. After poking around some I found that a couple of simple API calls would give me everything I needed to get the files, thus this script was born. It's still very rough but it's coming along as I take the time to work on it.

Right now, the perl script expects a file `.humblebundle.cfg` to be found in the current directory.  This file should look like this:

```
saveDir: "/path/to/save/folder"
sessionCookie: "RtWiGoxMjcyxZmkIjoiOTMzd9Jl1138d190... the value of the session cookie, see below"
maxFileSize: 4294967296
```

The download script currently downloads files into memory before checking the downloaded MD5 and creating a local file.  The maximum file size setting (in bytes) is used to prevent running out of memory and can be left out.  If left out, it defaults to 4 GB as shown in the example above.  The save directory and session cookie values are not optional.

To get the session cookie value, log into the HumbleBundle web site in your browser, then hit the F12 key to open the JavaScript debugger/inspector (this works in most non-mobile browsers).  Look for the value of the cookie named `_simpleauth_sess`.  Copy the value of that cookie into the configuration file, making sure it is all on one line in the configuration file.

The save directory must exist before running the script.

Contributions very much welcome.

## TODO
* Ask to set a download path, save in the .humblebundle.cfg file
* Get the sessionID cookie via an API call instead of logging in via a browser and logging in manually
* Put more work in to cleaning up the file names, maybe make it optional for those that don't care about spaces/etc in the filenames
* Ask if the directory name created is fine, let the user edit it
* Make the script portable between OS types? Not important to me exactly, but I'm sure someone else would like it
* Download huge files directly to disk rather than skipping them
* Make it possible to download only certain file types, or to skip certain file types
* Maybe make the save directory if it does not exist

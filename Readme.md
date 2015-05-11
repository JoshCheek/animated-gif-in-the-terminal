Animated Gifs In The Terminal
=============================

What?
-----

![screencap](screencap.gif)

Try
---

```sh
$ curl -sL http://bit.ly/1DRCK7q | ruby -
```

Install
-------

```sh
$ brew install imagemagick               # C dependency for reading gifs
$ bundle                                 # Get the Ruby dependencies
$ rspec                                  # Run the tests
$ bin/gif2rb examples/nyan.gif | ruby -  # Run the binary
```

Run
---

```sh
# see all options
$ bin/gif2rb -h

# run the owl
$ bin/gif2rb examples/owl.gif | ruby -

# run the kitten with highest quality pixels
$ bin/gif2rb examples/kitten.gif -s sharp | ruby -
```

Steal
-----

[wtfpl](http://www.wtfpl.net/about/).

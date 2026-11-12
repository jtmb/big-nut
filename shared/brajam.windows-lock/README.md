# Windows lock screen service

This service is a copy of Omarchy's `omarchy.lock` plugin (MIT licensed,
Omarchy project), with a Windows 10 layout added:

- large clock and date at the lower left
- avatar and user name above the password field
- sleep, restart and shutdown controls at the lower right
- optional white field styling supplied by `shell.lock.toml`

The PAM password flow and fingerprint support are unchanged from Omarchy.

The plugin uses its own manifest id (`brajam.windows-lock`) while keeping the
`lock` IPC target, so `omarchy-system-lock`, idle locking and
`omarchy-shell lock …` continue to work. The first-party `omarchy.lock` is
disabled while the Windows theme is active. Because Omarchy keeps lock
services loaded, a shell restart is required after applying or removing this
plugin.

## Licence

MIT License

Copyright (c) Omarchy contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

# Connecting from osu!
You can play on <%= brand.name %> using osu!stable.

1. Create a shortcut to `osu!.exe`.
2. Open the shortcut properties and add the `-devserver` argument to the end of the **Target** field:

```
C:\Users\user\AppData\Local\osu!\osu!.exe -devserver <%= (brand.url:gsub("^https?://", "")) %>
```

Replace the path with the actual location of your game if it is installed elsewhere.

3. [Log in on the website](/login) at least once. This creates your account.
4. Launch osu! using the new shortcut and log in with your <%= brand.name %> account.

Always use this shortcut to play on <%= brand.name %>. Launching osu! normally connects to the official servers.

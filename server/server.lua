RegisterCommand("servertest", function()
    print("Server side hello world!")
end, false)

RegisterCommand("bilgiyaz",function (source, args, row)
    print("Gelen Args:" ..table.concat(args, " "))
    print("Ham Komut", row)
end)
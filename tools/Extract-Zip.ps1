function Extract-Zip
{
    param(
        [parameter(mandatory=$true)] [string] $file,
        # default value for the destination directory is the script path and the name of the ZIP file
        [string] $destination = (Join-Path $PSScriptRoot ([System.IO.Path]::GetFileNameWithoutExtension($file)))
    )

    # make sure the destination directory exists
    New-Item -ItemType Directory -Force -Path $destination | Out-Null

    $shell = new-object -com shell.application
    $zip = $shell.NameSpace($file)

    foreach($item in $zip.items())
    {
        $shell.Namespace($destination).copyhere($item)
    }
}

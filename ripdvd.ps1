param (
	[Parameter(Position=0)][String]$InputFile,
	[String]$DvdDrive = "e",
	[String]$VlcPath = "C:\Program Files\VideoLAN\VLC\vlc.exe",
	[Parameter(ValueFromPipeline=$true)]$data
)
if ($InputFile -and !$data)
{
	$data = Get-Content $InputFile
}
$Dvd = $data[0] | ConvertFrom-CSV -Delimiter `t -Header "Type","Title","Creator"
if ($Dvd.Type = "music")
{
	$Artist = $Dvd.Creator
	$Title = $Dvd.Title
	$Path = $Title
	If ($Artist)
	{
		$Path = ".\" + $Artist + " - " + $Path
	}
}
New-Item -Type directory -Path $Path
Copy-Item -Path $InputFile -Destination $Path
$Tracks = $data[1..($data.length - 1)] | ConvertFrom-CSV -Delimiter `t -Header "Artist","Title","Start","End"
$Pad = ""
if ($Tracks.length -gt 9)
{
	$Pad += "0"
}
if ($Tracks.length -gt 99)
{
	$Pad += "0"
}
$Pos = 0
$CommandArgs = @()
($Tracks) | ForEach-Object {
	$Pos += 1
	$TitleChapter = $_.Start + "-" + $_.End
	If (!$_.End)
	{
		$TitleChapter += $_.Start
	}
	if ($_.Artist)
	{
		$Artist = $_.Artist
	}
	If ($_.Title)
	{
		$Title = $_.Title
	}
	$CommandArgs += "dvdsimple:///" + $DvdDrive + ":/#" + $TitleChapter
	$DestPos = $Pad + $Pos
	$DestPos = $DestPos.substring($DestPos.Length - $Pad.Length - 1)
	$DestInputFile = $Path + "\" + $DestPos + " " + $Artist + " - " + $Title + ".mp4"
	$DestInputFile = "'" + ((($DestInputFile  -replace "\\", "/") -replace "'", "\'") -replace "`"", "\'\'") + "'"
	$CommandArgs += ":sout=#transcode{vcodec=h264,fps=25,deinterlace,acodec=mp3,ab=128,samplerate=48000}:std{access=file,mux=ts,dst=" + $DestInputFile + "}"
}
$CommandArgs += "vlc://quit"
& $VlcPath $CommandArgs



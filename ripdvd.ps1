param (
	[Parameter(Position=0)][String]$InputFile,
	[String]$DvdDrive = "e",
	[String]$VlcPath = "C:\Program Files\VideoLAN\VLC\vlc.exe",
	[Parameter(ValueFromPipeline=$true)]$data,
	[String]$Encode = "mp4",
	[String]$AudioEncode,
	[String]$VideoEncode
)
if ($InputFile -and !$data)
{
	$data = Get-Content $InputFile
}
$Encodings = @{
	mp4 = @{
		Audio = "aac";
		Video = "h264";
		Mux = "mp4";
		Extension = "mp4"
	};
	mpg = @{
		Audio = "mpg2a";
		Video = "mpg2v";
		Mux = "ps";
		Extension = "mpg"
	}
}
$Encoding = $Encodings.$Encode
if (!$AudioEncode) {
	$AudioEncode = $Encoding.Audio
}
if (!$VideoEncode) {
	$VideoEncode = $Encoding.Video
}
$EncodeStrings = @{
	h264 = "vcodec=h264,fps=25,vfilter=deinterlace";
	aac = "acodec=mp4a,ab=128,samplerate=48000";
	mpg2v = "vcodec=mpgv,fps=25,vfilter=deinterlace";
	mp3 = "acodec=mp3,ab=128,samplerate=48000";
	mpg2a = "acodec=mpga,ab=192,samplerate=48000"
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
$CommandArgs = @("--sout-deinterlace-mode=yadif2x")
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
	$DestInputFile = $Path + "\" + $DestPos + " " + $Artist + " - " + $Title + "." + $Encoding.Extension
	$DestInputFile = "'" + ((($DestInputFile  -replace "\\", "/") -replace "'", "\'") -replace "`"", "\'\'") + "'"
	$CommandArgs += ":sout=#transcode{" + $EncodeStrings.$VideoEncode + "," + $EncodeStrings.$AudioEncode + "}:std{access=file,mux=" + $Encoding.Mux + ",dst=" + $DestInputFile + "}"
}
$CommandArgs += "vlc://quit"
& $VlcPath $CommandArgs



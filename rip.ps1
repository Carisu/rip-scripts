Function global:Rip-Drive
{
	[CmdletBinding()]Param
	(
		[Parameter(Position=0)][String]$InputFile,
		[String][ValidateSet("CD", "DVD")]$Type = "DVD",
		[String]$Drive = "e",
		[String]$VlcPath = "C:\Program Files\VideoLAN\VLC\vlc.exe",
		[Parameter(ValueFromPipeline=$true)][String[]]$Data,
		[String][ValidateSet("mp4", "mpg")]$Encode = "mp4",
		[String][ValidateSet("aac", "mp3", "mpg2a")]$AudioEncode,
		[String][ValidateSet("h264", "mpg2v")]$VideoEncode,
		[String]$Prefix = "",
		[int]$StartPosition = 0
	)

	Function getEncoding
	(
		[Parameter(Mandatory=$true)][String]$Encode,
		[Parameter(Mandatory=$true)][String]$Type,
		[String]$AudioEncode,
		[String]$VideoEncode
	)
	{
		$Encodings = @{
			DVD = @{
				mp4 = @{
					Audio = "aac";
					Video = "h264";
					Mux = "mp4";
					Extension = "mp4"
				};
				mpg = @{
					Audio = "mpg2a";
					Video = "mpg2v";
					Mux = "ts";
					Extension = "mpg"
				}
			};
			CD = @{
				mp4 = @{
					Audio = "aac";
					Mux = "mp4";
					Extension = "m4a"
				};
				mpg = @{
					Audio ="mp3";
					Mux = "dummy";
					Extension = "mp3"
				}
			}
		}
		$EncodeParams = @{
			h264 = @{
				vcodec = "h264"
			};
			aac = @{
				acodec = "mp4a";
				ab = 128
			};
			mpg2v = @{
				vcodec = "mpgv"
			};
			mp3 = @{
				acodec = "mp3";
				ab = 128
			};
			mpg2a = @{
				acodec = "mpga";
				ab = 192
			}
		}
		
		$Encoding = $Encodings.$Type.$Encode
		if ($AudioEncode)
		{
			$Encoding.Audio = $AudioEncode
		}
		if ($VideoEncode)
		{
			$Encoding.Video = $VideoEncode
		}
		
		$Encoding.Params = $EncodeParams.($Encoding.Audio)
		If ($Encoding.Video)
		{
			$Encoding.Params += $EncodeParams.($Encoding.Video)
		}
		if ($Type -eq "DVD")
		{
			$Encoding.Params.fps = 25
			$Encoding.Params.vfilter = "deinterlace"
			$Encoding.Params.samplerate = 48000
		} else {
			$Encoding.Params.samplerate = 44100
		}

		$Encoding.Params | Out-Host
		$Encoding
	}

	Function getDiscHeader
	(
		[Parameter(Mandatory=$true)][String]$Type
	)
	{
		$Headers = @{
			DVD = "Type","Title","Creator";
			CD = "Type","Title","Creator","Extra"
		}
		
		$Headers.$Type
	}
		
	Function getTrackHeader
	(
		[Parameter(Mandatory=$true)][String]$Type,
		[Parameter(Mandatory=$true)][String]$DiscType
	)
	{
		$Headers = @{
			DVD = @{
				music = "Artist","Title","Start","End";
				film = "Start","End";
				series = "Title","Start","End"
			};
			CD = @{
				music = "Artist","Title","Extra"
			}
		}
		
		$Headers.$Type.$DiscType
	}

	Function decode
	(
		[Parameter(Mandatory=$true)][String]$Details,
		[Parameter(Mandatory=$true)][String[]]$Header
	)
	{
		$Details | ConvertFrom-CSV -Delimiter `t -Header $Header
	}

	Function discDetails
	(
		[Parameter(Mandatory=$true)][String]$Type,
		[Parameter(Mandatory=$true)][String]$DiscType,
		[Parameter(Mandatory=$true)][Object]$Disc
	)
	{
		$Details = @{
			Position = "";
			Title = $Disc.Title;
			Subtitle = $Disc.Creator
		}
		if ($Type -eq "DVD")
		{
			$Details.Option = ""
		}
		if ($Type -eq "CD")
		{
			$Details.Option = $Disc.Extra
		}
		
		$Details
	}

	Function trackDetails
	(
		[Parameter(Mandatory=$true)][String]$Type,
		[Parameter(Mandatory=$true)][String]$DiscType,
		[Parameter(Mandatory=$true)][int]$RealPosition,
		[String]$Position = "",
		[Parameter(Mandatory=$true)][Object]$Track,
		[Parameter(Mandatory=$true)][Object]$Previous
	)
	{
		$Details = @{
			Position = $Position
		}
		if ($DiscType -eq "music")
		{
			$Details.Title = $Track.Title
			$Details.Subtitle = $Track.Artist
			if (!$Details.Title) {
				$Details.Title = $Previous.Title
			}
			if (!$Details.SubTitle) {
				$Details.SubTitle = $Previous.SubTitle
			}
		}
		if ($DiscType -eq "film")
		{
			$Details.Title = $Previous.Title
		}
		if ($DiscType -eq "series")
		{
			$Details.Option = $Track.Title
			$Details.Title = $Previous.Title
			if (!$Details.Title)
			{
				$Details.Title = $Previous.Title
			}
		}
		if ($Type -eq "DVD")
		{
			$Start = $Track.Start -replace " ", ""
			$End = $Start
			If ($_.End)
			{
				$End = $Track.End -replace " ", ""
			}
			$Details.TitleChapter = $Start + "-" + $End
		}
		if ($Type -eq "CD")
		{
			$Details.Option = $Track.Extra
			$Details.Track = $RealPosition
		}
		
		$Details
	}

	Function generateDetails
	(
		[Parameter(Mandatory=$true)][String]$Type,
		[Parameter(Mandatory=$true)][String]$DiscType,
		[Parameter(Mandatory=$true)][Object]$Disc,
		[String]$Pad,
		[String]$Prefix,
		[int]$StartPosition,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true)][Object[]]$Tracks	
	)
	{
		Begin
		{
			$Count = 0
			$Details = @{
				Disc = discDetails -Type $Type -DiscType $DiscType -Disc $Disc;
				Tracks = @()
			}
			$Previous = $Details.Disc
		}
		
		Process
		{
			$Previous | Out-Host
			$Count += 1
			$Pos = ""
			if ($DiscType -ne "film")
			{
				$Pos = $Pad + ($Count + $StartPosition)
				$Pos = $Prefix + $Pos.substring($Pos.Length - $Pad.Length - 1)
			}
			$Previous = trackDetails -Type $Type -DiscType $DiscType -RealPosition $Count -Position $Pos -Track $_ -Previous $Previous
			$Details.Tracks += $Previous
		}
		
		End
		{
			$Details
		}
	}

	Function createPath
	(
		[Parameter(Mandatory=$true)][Object]$Details,
		[Parameter(Mandatory=$true)][String]$FolderPath,
		[String]$Extension = ""
	)
	{
		$Position = $Details.Position
		$SubTitle = $Details.Subtitle
		$Title = $Details.Title
		$Option = $Details.Option
		if ($Position)
		{
			$Position += " "
		}
		if ($SubTitle)
		{
			$SubTitle += " - "
		}
		if ($Option)
		{
			$Option = " (" + $Option + ")"
		}
		$FolderPath + $Position + $SubTitle + $Title + $Option + $Extension
	}

	Function fixPath
	(
		[Parameter(Mandatory=$true,ValueFromPipeline=$true)][String]$Path,
		[switch]$Quote
	)
	{
		$NewPath = ($Path  -replace "\\", "/") -replace "`"", "''"
		if ($Quote)
		{
			$NewPath = "'" + ($NewPath -replace "'", "\'") + "'"
		}
		$NewPath
	}

	Function generateTrackPaths
	(
		[Parameter(Mandatory=$true,ValueFromPipeline=$true)][Object[]]$Details,
		[Parameter(Mandatory=$true)][String]$FolderPath,
		[Parameter(Mandatory=$true)][String]$Extension
	)
	{
		Begin
		{
			$TrackPaths = @()
		}
		
		Process
		{
			$TrackPaths += createPath -Details $_ -FolderPath ($FolderPath + "\") -Extension ("." + $Extension) | fixPath -Quote
		}
		
		End
		{
			$TrackPaths
		}
	}

	Function generatePaths
	(
		[Parameter(Mandatory=$true)][Object]$Details,
		[Parameter(Mandatory=$true)][String]$Extension
	)
	{
		$Disc = createPath -Details $Details.Disc -FolderPath ".\" | fixPath
		$Disc | Out-Host
		@{
			Disc = $Disc;
			Tracks = $Details.Tracks | generateTrackPaths -FolderPath $Disc -Extension $Extension
		}
	}

	Function createDir
	(
		[Parameter(Mandatory=$true)][String]$DiscPath,
		[Parameter(Mandatory=$true)][String]$DiscType,
		[String]$Prefix,
		[int]$StartPosition,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true)][String[]]$Data
	)
	{	
		Begin
		{
			$Output = ""
		}
		
		Process
		{
			$Output += $Data + "`n"
		}
		
		End
		{
			if (!(Test-Path $DiscPath))
			{
				New-Item -Type directory -Path $DiscPath | Out-Null
			}
			$File = $DiscPath.substring(1)
			$FilePath = $DiscPath + $File + " (" + $DiscType
			if ($Prefix)
			{
				$FilePath += " " + $Prefix
			}
			if ($StartPosition)
			{
				$FilePath += " from " + ($StartPosition - 1)
			}
			$FilePath += ").txt"
			if (Test-Path $FilePath)
			{
				Remove-Item -Path $FilePath
			}
			New-Item -Type file -Path $FilePath -Value $Output | Out-Null
		}
	}
	
	Function updateTracks
	(
		[Parameter(Mandatory=$true)][Object[]]$Tracks,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true)][String[]]$TrackPaths
	)
	{
		Begin
		{
			$Pos = 0
		}
		
		Process
		{
			$Tracks[$Pos++].Filename = $_
		}
		
		End
		{
			$Tracks
		}
	}
	
	Function generateParamString
	(
		[Parameter(Mandatory=$true)][Object]$Params
	)
	{
		$ParamsString = ""
		$Join = ""
		$Params.getenumerator() | ForEach-Object {
			$ParamsString += $Join + $_.Name + "=" + $_.Value
			$Join = ","
		}

		$ParamsString
	}

	Function generateParams
	(
		[Parameter(Mandatory=$true)][String]$Type,
		[Parameter(Mandatory=$true)][String]$Drive,
		[Parameter(Mandatory=$true)][Object]$Encoding,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true)][Object[]]$Tracks
	)
	{
		Begin
		{
			$Params = @()
			$MrlProtocol = @{
				DVD = "dvdsimple";
				CD = "cdda"
			}
			if ($TYpe -eq "DVD")
			{
				$Params += "--sout-deinterlace-mode=yadif2x"
			}
			$EncodeParams = generateParamString -Params $Encoding.Params
		}
		
		Process
		{
			$MrlParam = $MrlProtocol.$Type + ":///" + $Drive + ":/"
			if ($Type -eq "DVD")
			{
				$MrlParam += "#" + $_.TitleChapter
			}
			$Params += $MrlParam
			if ($Type -eq "CD")
			{
				$Params += ":cdda-track=" + $_.Track
			}
			$Params += ":sout=#transcode{" + $EncodeParams + "}:std{access=file,mux=" + $Encoding.Mux + ",dst=" + $_.Filename + "}"
		}
		
		End
		{
			$Params += "vlc://quit"

			$Params
		}
	}
	
	Function getPadding
	(
		[int]$Length
	)
	{
		$Pad = ""
		if ($Length -gt 9)
		{
			$Pad += "0"
		}
		if ($Length -gt 99)
		{
			$Pad += "0"
		}
		
		$Pad
	}

	Function ripDrive
	{
		Param
		(
			[Parameter(Mandatory=$true)][String]$Type,
			[Parameter(Mandatory=$true)][String]$Drive,
			[Parameter(Mandatory=$true)][String]$VlcPath,
			[Parameter(Mandatory=$true,ValueFromPipeline=$true)][String[]]$Data,
			[Parameter(Mandatory=$true)][String]$Encode,
			[String]$AudioEncode,
			[String]$VideoEncode,
			[String]$Prefix,
			[int]$StartPosition
		)

		Begin
		{
			$AllData = @()
			$Tracks = @()
			$Encoding = getEncoding -Type $Type -Encode $Encode -AudioEncode $AudioEncode -VideoEncode $VideoEncode
			$DiscHeader = getDiscHeader -Type $Type
			$Continue = $true
		}

		Process
		{
			$AllData += $_
			if (!$Disc)
			{
				$Disc = decode -Details $_ -Header $DiscHeader
				$TrackHeader = getTrackHeader -Type $Type -DiscType $Disc.Type
			} else {
				$Continue = $Continue -and ($_ -ne "=====")
				if ($Continue)
				{
					$Tracks += decode -Details $_ -Header $TrackHeader
				}
			}
		}

		End
		{
			$AllData | Out-Host
			$Disc | Out-Host
			$Tracks | Out-Host
			$Details = $Tracks | generateDetails -Type $Type -DiscType $Disc.Type -Disc $Disc -Prefix $Prefix -StartPosition $StartPosition -Pad (getPadding -Length ($Tracks.length + $StartPosition))
			$Details.Disc | Out-Host
			$Details.Tracks[0] | Out-Host
			$Details | Out-Host
			$Paths = generatePaths -Details $Details -Extension $Encoding.Extension
			$Paths | Out-Host
			$AllData | createDir -DiscPath $Paths.Disc -DiscType $Disc.Type -Prefix $Prefix -StartPosition $StartPosition
			$VlcParams = $Paths.Tracks | updateTracks -Tracks $Details.Tracks | generateParams -Type $Type -Drive $Drive -Encoding $Encoding
			$VlcParams | Out-Host
			
			& $VlcPath $VlcParams
			
			$Details
		}
	}
	
	$FileData = $Data
	if ($InputFile -and !$Data)
	{
		$FileData = Get-Content $InputFile
	}
	if ($StartPosition)
	{
		$StartPosition--
	}
	$FileData | ripDrive -Type $Type -Drive $Drive -VlcPath $VlcPath -Encode $Encode -AudioEncode $AudioEncode -VideoEncode $VideoEncode -Prefix $Prefix -StartPosition $StartPosition
}

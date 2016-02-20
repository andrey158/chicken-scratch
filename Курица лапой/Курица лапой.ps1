$current_path = [string](Split-Path $script:MyInvocation.MyCommand.Path) + "\"
$storage_path = $current_path + "episodes\"
$episodes_file = $storage_path + "episodes.xml"

function Get-NewItems{ param([System.Xml.XmlDocument]$Episodes)
	$base_url = "http://www.radiorus.ru/brand/audio/id/57260/page/"

	# Узнаём количество страниц:
	$page_url = $base_url + "1"

	[Microsoft.PowerShell.Commands.HtmlWebResponseObject]$page_content = Invoke-WebRequest -Uri $page_url

	# Последняя страница:
	$paginator = $page_content.AllElements | Where-Object {$_.tagName -eq "DIV" -and $_.class -eq "paginator"} | Select-Object -First 1 # первый список страниц (их на странице два)
	$pages = $paginator.innerText.Split("`n") | Select-Object -Last 1 # последний элемент в списке страниц

	# Загружаем XSL:
	$XSLTrans = New-Object System.Xml.Xsl.XslCompiledTransform
	$XSLTSettings = New-Object System.Xml.Xsl.XsltSettings
	$XmlUrlResolver = New-Object System.Xml.XmlUrlResolver
	$XsltSettings.EnableScript = $true
	$xsl_path = $current_path + "Transformation.xsl"
	$XSLTrans.Load($xsl_path, $XsltSettings, $XmlUrlResolver)

	[System.Xml.XmlElement]$ResultItems = $Episodes.LastChild

	# Обрабатываем все страницы передачи:
	for ($page_number = 1; $page_number -le $pages; $page_number++) {

		Write-Progress -Activity "Получение списка эпизодов" -status "Обрабатывается страница $page_number из $pages" -percentComplete ($page_number / $pages*100)

		$page_url = $base_url + $page_number

		Write-Host "Страница", $page_number, $page_url

		# считываем страницу
	    [Microsoft.PowerShell.Commands.HtmlWebResponseObject]$page_content = Invoke-WebRequest -Uri $page_url

		# раздел страницы со списком передач:
		$audio_element_lists = $page_content.AllElements | Where-Object {$_.tagName -eq "DIV" -and $_.class -eq "audio-element-list"}

		[string]$html = ""
		$audio_element_lists | ForEach-Object { $html = $html + $_.outerHTML }

		# Причёсываем HTML-код для повышения валидности
		$html = [regex]::Replace($html, "<(img.*?)>", '<$1/>')                     # Закрываем незакрытые теги IMG
		$html = $html.Replace("<br>", "")
		$html = $html.Replace("</br>", "")
		$html = $html.Replace("<hr>", "")
		$html = $html.Replace("</hr>", "")
		$html = $html.Insert(0, "<!DOCTYPE html [<!ENTITY nbsp ""&#160;"">]>")

		$CurrentXML = New-Object System.Xml.XmlDocument
		$CurrentXML.LoadXml($html)

		#Готовим место для результата:
		$ResultXML = New-Object System.Xml.XmlDocument
		$MemStream = New-Object System.IO.MemoryStream

		$XMLWriter = [System.Xml.XmlWriter]::Create($MemStream)

		# Парсим:
		$XSLArg = New-Object System.Xml.Xsl.XsltArgumentList
		$XSLArg.Clear() 
		$XSLTrans.Transform($CurrentXML, $XSLArg, $XMLWriter)

		$XMLWriter.Flush()
		$MemStream.Position = 0

		# Результат:
		$ResultXML.Load($MemStream) 
		[xml]$Items = $ResultXML.Get_OuterXML()

		#$Items.Items.Item | Format-Table -AutoSize

		$Items.Items.Item | ForEach-Object {		
			$_
			# Такой элемент уже есть?
			$xpath = "item[episode_id='"+[string]$_.episode_id+"']"
			$node = $ResultItems.SelectSingleNode($xpath)
			if ($node -eq $null) {
				[System.Xml.XmlNode]$newItem = $Episodes.ImportNode($_, $true)
				$ResultItems.AppendChild($newItem) | Out-Null
			}
		}
	}

	$Episodes.Save($episodes_file)
}

function Load-Items{ param([System.Xml.XmlDocument]$Episodes)
	$taglib = $current_path +"taglib-sharp.dll"
	[system.reflection.assembly]::LoadFile($taglib) | Out-Null

	$wc = New-Object System.Net.WebClient
	$Episodes.Items.Item | Where-Object{$_.downloaded -eq $false} | ForEach-Object {

		if ($_.audio -eq "" -or $_.name -eq "") {
			$_.SetAttribute("downloaded", $true)
			continue
		}
 
		$audio_file = $storage_path + $_.date + " " + $_.name + ".mp3"
		$img_file = $storage_path + $_.name + ".jpg"
		try {
			$wc.DownloadFile($_.audio, $audio_file)

			$media = [TagLib.File]::Create($audio_file)
			$media.Tag.Album = "Как курица лапой"
			$media.Tag.Title = $_.name
			#$media.Tag.AlbumArtists = "Как курица лапой"
			$media.Tag.Comment = $_.description

			if ($_.img -ne "") {
				$wc.DownloadFile($_.img, $img_file)
				$pic = [TagLib.Picture]::createfrompath($img_file) 
				$media.Tag.Pictures = $pic
			} 
			$media.Save( )
			$_.SetAttribute("downloaded", $true)
		} catch [Exception] {}
		
	}
	$Episodes.Save($episodes_file)

	Remove-Item ($storage_path + "*.jpg")
}

if ((Test-Path $storage_path) -eq $false) {
	New-Item -ItemType Directory -Force -Path $storage_path
}

# Список эписодов:
$Episodes = New-Object System.Xml.XmlDocument
try {
	$Episodes.Load($episodes_file)
} catch [Exception] {
	$Episodes.LoadXml("<Items/>")
}

Get-NewItems $Episodes
#Load-Items $Episodes

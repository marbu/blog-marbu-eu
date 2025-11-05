---
title: Copernicus Sentinel, Drought and Copyright
tags: translated, backdated
updated: 2025-11-05T23:34:56+01:00
...

At the end of July, a comparison of 2 satellite images taken about a month
apart was featured by various news sites, showing how this year's drought
affected vegetation in the landscape during that time. And even though this
alone is quite enlightening, I want to look at it from the perspective of
referencing primary sources and using open data. Considering the ongoing
copyright reform, this is also somewhat topical.

<!--more-->

## From Green to Brown

This image, based on data from the [Sentinel
3](https://en.wikipedia.org/wiki/Sentinel-3) satellite, was published on July
26, 2018 in the [Space in Images](http://www.esa.int/spaceinimages/Images)
section of the ESA website as [From green to brown in a
month](http://www.esa.int/spaceinimages/Images/2018/07/From_green_to_brown_in_a_month),
including a summary of what's shown in the image and a link to a 10MB jpeg in
full resolution.

![](/images/From_green_to_brown_in_a_month_node_full_image_2.jpg)

Czech news websites that I managed to find (this is by no means a complete
list) picked up this image the following day, July 27, as:

* aktualne.cz: [From green to brown. Satellite images revealed how drought changed Europe's face](https://zpravy.aktualne.cz/zahranici/prekryvacka-sucho/r~0667fd6c917511e8915e0cc47ab5f122/)
* idnes.cz: [Scorched continent. Satellites showed how record heat is decimating Europe](https://zpravy.idnes.cz/pozary-sucho-evropa-satelity-snimky-druzice-fn5-/zahranicni.aspx?c=A180727_122334_zahranicni_aha)
* novinky.cz: [Sweltering heat afflicts all of Europe](https://www.novinky.cz/zahranicni/evropa/479017-umorna-vedra-suzuji-celou-evropu.html)
  (the article uses a different satellite image, but that doesn't change
  anything fundamental)
* zive.cz: [Europe turned brown: Sentinel-3 satellite photographed it in June and now](https://vtm.zive.cz/clanky/evropa-zhnedla-druzice-sentinel-3-ji-vyfotila-v-cervnu-a-ted/sc-870-a-194339/default.aspx)
* in-pocasi.cz: [Western Europe faces heat wave, temperatures reach 38°C](https://www.in-pocasi.cz/clanky/vyznacne/vlna-veder-27.7.2018/)

Note that the [standard license terms for images from the ESA
website](http://www.esa.int/spaceinimages/ESA_Multimedia/Copyright_Notice_Images)
do not permit unrestricted commercial use (you will have a problem using it in
advertising or if someone is recognizable in the image), but republishing in
newspapers, Wikipedia, or on a blog is imho ok, provided you credit ESA as the
author of the image, preferably including the satellite name. Btw it's nice
that another license ESA uses for some images is [Creative Commons
Attribution-ShareAlike 3.0
IGO](https://creativecommons.org/licenses/by-sa/3.0/igo/).

In other words, it's basically enough to write something like "Image:
ESA/Copernicus Sentinel" next to the photo in the article. That said ideally
I'd expect to learn:

* That the author is ESA,
* The name of the satellite or satellite constellation (the sheer name is
  sufficient),
* A link to the original source, that is a URL that helps me to find both the
  original version of the image and the license under which the image is
  published (however, if the photo were published under a Creative Commons
  license, I'd expect a direct link to the license as well).

Of those 5 articles, only zive.cz and in-pocasi.cz did this, while the others
at least more or less complied with the license and credited ESA as the source
of the image, although:

* aktualne.cz doesn't mention what satellite it is (on the other hand, the
  license doesn't directly require this),
* idnes.cz in the first paragraph also writes that these are *aerial* images :)
* novinky.cz gives profimedia.cz as the source, which is somewhat strange ...

And this makes me wonder: Why is it such a problem nowadays to include a full
link to the source in an internet article? I understand that back when
newspapers only came out on paper, it simply wasn't possible to reference
sources better, but today a reader often has online access to the source as
easy as the author. This seems to me like some historical relic, or laziness.
The author doesn't save much work and it only reduces their credibility,
because it's not possible to:

* get an idea of whether the author of the article actually used the primary
  source
* look up details if the article interests me (eg. in this case I might want to
  download the original high-resolution version)
* find out under what license the source is available (eg. so I could use the
  photo further in accordance with the license, for instance for another
  similar comparison), without having to ask the author of the article (who
  doesn't actually hold the copyright to that photo anyway)
* verify claims in the article (here for example how newspapers interpreted the
  photo compared to what ESA claims)
* directly search for articles based on the source used (e.g., I might be
  interested in whether someone else used the same source in a different
  context)

But to be clear, I don't expect journalists to search for and link to internet
sources for every trivial matter, when much of the verification and
journalistic work in general doesn't happen on the internet. But if they're
already working with some non-trivial information that they obtained via the
internet and it is available to anyone, why not link to it? Moreover, if an
author has already used some source, it seems unprofessional not to cite it or
mention it without a full link. On the other hand, if the author doesn't cite a
source because they don't actually know it, there's no point discussing any
trustworthiness.

## Copernicus Sentinel

The reason why it's useful to know which satellite the image comes from is that
within the [Copernicus
Programme](https://en.wikipedia.org/wiki/Copernicus_Programme), which [includes
the Sentinel satellites](https://sentinels.copernicus.eu), [a large portion of
the acquired data is freely
available](https://www.copernicus.eu/en/access-data/conventional-data-access-hubs).
The [license of this
data](https://sentinels.copernicus.eu/documents/247904/690755/Sentinel_Data_Legal_Notice)
then allows you to do anything with it, provided you reference the Copernicus
Sentinel project in the prescribed format and indicate whether you have
modified or processed the data in any way.

This caught my attention, so I thought I'd try to download the source satellite
data for the image that went through the newspapers in July. Maybe later I'll
devote a separate post to a detailed description of how I downloaded the data
and tried to process it (i.e., at least display it somehow). However, it
quickly became apparent that this isn't exactly straightforward. Nevertheless,
it's nice that this data is available this way, including documentation and
various tutorials, and that [the software ESA develops for processing this
data](http://step.esa.int/main/download/) is licensed under GPLv3.

On the one hand the images I managed to get from the data don't have as high
resolution as they theoretically could and on top of that look a bit strange,
but on the other hand I did an
[*uncrop*](https://www.google.com/search?q=red%20dwarf%20super%20enhance%20uncrop)
wrt the media famous picture, because it turned out it was composed of 2
consecutive satellite images :-)

![](/images/snap_compare_results1.png)

## Czech Radio Article

The availability of data from Sentinel satellites was later utilized for
example by [Czech Radio](https://en.wikipedia.org/wiki/Czech_Radio), which on
August 9 puslished an article titled [Less green, more brown. Compare how this
year's and last year's summer look from space in the Czech
Republic](https://www.irozhlas.cz/zpravy-domov/pocasi-praha-hradec-kralove-leto-2018-sucho-vedro_1808180600_ako).
This is imho the most interesting of all the articles about this year's drought
based on Sentinel satellite data, but it also must have required the most work.
And not just because the images in the article show the Czech Republic and not
Britain. If you want to read any of those articles, read this one.

And it probably won't surprise anyone that they have described the data sources
correctly, exactly according to the license :) If anyone was puzzled that I
don't mind the absence of an HTML link to the original source here, in this
case it's ok because the satellite images used in the radio article aren't
directly taken from some website, but were provided by a Czech GIS company
(which among other things processes Sentinel data), so no such URL exists.

## From the Copyright Reform Perspective

And finally, I'd allow myself a small digression. As you have probably noticed,
in September the [European Parliament voted on the copyright reform proposal
without significant
amendments](https://juliareda.eu/2018/09/ep-endorses-upload-filters/). So
unless all the nonsense there gets thrown out during the trilogue ([which isn't
very likely, quite the
opposite](https://juliareda.eu/2018/11/eu-council-upload-filters/)) or the
European Parliament throws the whole thing off the table eventually, we still
realistically face various not entirely pleasant outcomes soon.

In the context of this post, the funniest part probably is that if the articles
linked above were automatically indexed by an upload filter when published, I
might well have problems publishing this post on *information society service
provider storing and providing access to the public to large amounts of
copyright protected work*. Despite the fact that I use data in accordance with
the license and link to the primary source, while most newspaper articles
don't. But how could the upload filter recognize that?

In a similar way, I'd probably have problems with links to the articles because
I used a large part of the title in them. So I'd either have to buy the
appropriate license or use the URL as the link text. I allowed myself to reject
the possibility of inventing a new title for each article to avoid the
obligation to license it. But in this case it probably doesn't matter anyway,
because if bulk automated processing of articles were restricted, I wouldn't
even be able to find which articles used that satellite image in the given time
period, and so I wouldn't have anything to link to.

&lt;irony&gt;
I can already see how this will help to fight misleading news, help to increase
publishers' profits, and improve media quality in general. Maybe it wouldn't be
a bad idea to also require newspapers to use the same upload filter before
publishing articles for further improvement of the situation.
&lt;/irony&gt;

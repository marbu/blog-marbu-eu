--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
import           Control.Monad (filterM)
import           Data.Functor.Identity (runIdentity)
import           Data.Monoid (mappend)
import           Data.Ord (comparing)
import           Data.Map (Map)
import qualified Data.Map as Map
import           Data.List
import qualified Data.Text as T
import           System.FilePath.Posix
import           System.Process (system)
import           Hakyll
import           Hakyll.Web.Pandoc
import           Hakyll.Web.Tags
import           Text.Pandoc ( Pandoc
                             , Inline(Link)
                             , Block(Header)
                             )
import           Text.Pandoc.Walk (walk)
import           Text.Pandoc.Shared (stringify)
import           Text.Pandoc.Options ( WriterOptions
                                     , writerNumberSections
                                     , writerTOCDepth
                                     , writerTableOfContents
                                     , writerTemplate
                                     )
import           Text.Pandoc.Templates ( Template
                                       , compileTemplate
                                       )

--------------------------------------------------------------------------------
siteName = "blog.marbu.eu"
siteURL  = "https://" ++ siteName

myHakyllConfig :: Configuration
myHakyllConfig = defaultConfiguration
    { deployCommand = "bash deploy.sh " ++ siteName
    , deploySite    = system . deployCommand
    }

myFeedConfig :: FeedConfiguration
myFeedConfig = FeedConfiguration
    { feedTitle       = siteName
    , feedDescription = "marbu's blog feed"
    , feedAuthorName  = "Martin Bukatovič"
    , feedAuthorEmail = "martinb@marbu.eu"
    , feedRoot        = siteURL
    }

myFedoraFeedConfig :: FeedConfiguration
myFedoraFeedConfig = myFeedConfig
    { feedTitle       = siteName ++ "/fedora"
    , feedDescription = "marbu's blog feed with fedora related posts only"
    }

myTagDescMap :: Map String String
myTagDescMap = Map.fromList
  [ ("Fedora", "These posts are related to <a href='https://getfedora.org/'>Fedora GNU/Linux distribution</a> and <a href='https://en.wikipedia.org/wiki/The_Fedora_Project'>Fedora project</a> in general.")
  , ("reading-notes", "Sometimes when I stumble upon an interesting topic while reading a book, I look up more details and if it's really interesting, I may end up writing a short post about it.")
  , ("Ada", "Blogposts related to <a href='https://en.wikipedia.org/wiki/Ada_%28programming_language%29'>Ada programming language</a>.")
  , ("translated", "These posts were originaly published in my old blog in Czech language. Date shown here is the publication date of the original Czech version.")
  , ("pinned", "These posts are pinned on the main page in <i>Featured posts</i> section.")
  ]

--------------------------------------------------------------------------------
main :: IO ()
main = hakyllWith myHakyllConfig $ do
    match "images/*" $ do
        route   idRoute
        compile copyFileCompiler

    match "css/*" $ do
        route   idRoute
        compile compressCssCompiler

    match (fromList ["robots.txt", "favicon.ico"]) $ do
        route   idRoute
        compile copyFileCompiler

    match (fromList ["about.md", "acknowledgements.md"]) $ do
        route   $ setExtension "html"
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/default.html" myDefaultContext
            >>= relativizeUrls

    -- custom error pages
    match (fromList ["404.md"]) $ do
        route   $ setExtension "html"
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/default.html" myDefaultContext

    tags <- buildTags "posts/*" (fromCapture "tags/*.html")

    -- create page for each tag via tagsRules
    tagsRules tags $ \tag pattern -> do
        let title = "Posts tagged \"" ++ tag ++ "\""
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll pattern
            let minCtx =
                    listField "posts" (postCtxWithTags tags) (return posts) `mappend`
                    constField "title" title                                `mappend`
                    myDefaultContext
            let ctx = case Map.lookup tag myTagDescMap of
                 Nothing      -> minCtx
                 Just tagDesc -> minCtx `mappend` (constField "tagdesc" tagDesc)

            makeItem ""
                >>= loadAndApplyTemplate "templates/tag.html"     ctx
                >>= loadAndApplyTemplate "templates/default.html" ctx
                >>= relativizeUrls

    match "posts/*" $ do
        route $ niceRoute
        compile $ do
            identifier <- getUnderlying
            toc <- getMetadataField identifier "toc"
            let writerSettings = case toc of
                 Nothing     -> defaultHakyllWriterOptions
                 Just _      -> withTOC
            pandocCompiler
              >>= saveSnapshot "pristine"
            pandocCompilerWithTransform defaultHakyllReaderOptions writerSettings buildHeaderLinks
              >>= loadAndApplyTemplate "templates/post.html"    (postCtxWithTags tags)
              >>= saveSnapshot "content"
              >>= loadAndApplyTemplate "templates/default.html" (postCtxWithTags tags)
              >>= relativizeUrls

    create ["archive.html"] $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAllSnapshots "posts/*" "pristine"
            let archiveCtx =
                    listField "posts" (postCtxWithTags tags) (return posts) `mappend`
                    constField "title" "Archive"                            `mappend`
                    myDefaultContext

            makeItem ""
                >>= loadAndApplyTemplate "templates/archive.html" archiveCtx
                >>= loadAndApplyTemplate "templates/default.html" archiveCtx
                >>= relativizeUrls

    create ["sitemap.xml"] $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll "posts/*"
            singlePages <- loadAll (fromList ["about.md"])
            let pages = posts `mappend` singlePages
                sitemapCtx =
                    listField "pages" postCtx (return pages)   `mappend`
                    constField "root" siteURL
            makeItem ""
                >>= loadAndApplyTemplate "templates/sitemap.xml" sitemapCtx

    -- create tags page
    create ["tags.html"] $ do
        route idRoute
        compile $ do
            tagCloud <- renderTagCloud 90.0 270.0 tags
            let tagsCtx =
                    constField "tagcloud" tagCloud    `mappend`
                    constField "title" "Tags"         `mappend`
                    myDefaultContext

            makeItem ""
                >>= loadAndApplyTemplate "templates/tags.html"    tagsCtx
                >>= loadAndApplyTemplate "templates/default.html" tagsCtx
                >>= relativizeUrls

    create ["atom.xml"] $ do
        route idRoute
        compile $ do
            posts <- fmap (take 10) . recentFirst
                =<< loadAllSnapshots "posts/*" "content"
            renderAtom myFeedConfig feedCtx posts

    create ["fedora/atom.xml"] $ do
        route idRoute
        compile $ do
            posts <- fmap (take 10) . recentFirst
                =<< filterTag "Fedora"
                =<< loadAllSnapshots "posts/*" "content"
            renderAtom myFedoraFeedConfig feedCtx posts

    create ["fedora/index.html"] $ do
        route idRoute
        compile $ makeItem $ Redirect "/tags/Fedora.html"

    match "index.html" $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAllSnapshots "posts/*" "pristine"
            pinnedPosts <- filterTag "pinned" posts
            tagList <- renderTagList $ takeTags 6 $ sortTagsBy postNumTagSort tags
            let lastPosts = take 4 posts
                indexCtx =
                    listField "pinnedPosts" (postCtxWithTags tags) (return pinnedPosts) `mappend`
                    listField "posts" (postCtxWithTags tags) (return lastPosts) `mappend`
                    constField "taglist" tagList                                `mappend`
                    constField "canonical_url" siteURL                          `mappend`
                    myDefaultContext

            getResourceBody
                >>= applyAsTemplate indexCtx
                >>= loadAndApplyTemplate "templates/default.html" indexCtx
                >>= relativizeUrls

    match "templates/*" $ compile templateBodyCompiler

--------------------------------------------------------------------------------
myDefaultContext :: Context String
myDefaultContext =
    constField "root"    siteURL     `mappend`
    defaultContext

postCtx :: Context String
postCtx =
    dateField  "date"    "%e %B %Y"  `mappend`
    dateField  "isodate" "%Y-%m-%d"  `mappend`
    dropIndexHtml "url"              `mappend`
    myDefaultContext

postCtxWithTags :: Tags -> Context String
postCtxWithTags tags =
    tagsField "tags" tags            `mappend`
    teaserField "teaser" "pristine"  `mappend`
    postCtx

feedCtx :: Context String
feedCtx = postCtx `mappend` bodyField "description"

-- sort tags after number of posts in tag
postNumTagSort :: (String, [Identifier]) -> (String, [Identifier]) -> Ordering
postNumTagSort a b = comparing (length . snd) b a

-- get only given number of tags without the rest
takeTags :: Int -> Tags -> Tags
takeTags n tags = tags { tagsMap = (take n $ tagsMap tags) }

-- filter items by given tag
filterTag :: String -> [Item a] -> Compiler [Item a]
filterTag tag items = filterM (itemHasTag tag) items
  where itemHasTag tag item = do
          let ii = itemIdentifier item
          tags <- getTags ii
          return $ tag `elem` tags

-----------------------
-- table of contents --
-----------------------

withTOC :: WriterOptions
withTOC = defaultHakyllWriterOptions
        { writerNumberSections  = False
        , writerTableOfContents = True
        , writerTOCDepth        = 3
        , writerTemplate        = Just tocTemplate
        }

tocTemplate :: Text.Pandoc.Templates.Template T.Text
tocTemplate = either error id . runIdentity . compileTemplate "" $ T.unlines
  [ "<div class=\"article-toc\">Table of Contents:"
  , "$toc$"
  , "</div>"
  , "$body$"
  ]

--
-- header links (based on https://stackoverflow.com/questions/77944576)
--

transformHeader :: Block -> Block
transformHeader (Header level attr@(identifier, _, _) contents) | level > 1 =
    let linkClass = "headerLink"
        linkAttr = ("", [linkClass], [])
        linkDestination = "#" <> identifier
        linkTitle = stringify contents
    in Header level attr
            [ Link linkAttr contents (linkDestination, linkTitle)
            ]
transformHeader block = block

buildHeaderLinks :: Pandoc -> Pandoc
buildHeaderLinks = walk transformHeader

-------------------
-- nice url hack --
-------------------

-- replace "foo/bar.md" with "foo/bar/index.html"
-- this way the url looks like "foo/bar" in most browsers
-- see http://yannesposito.com/Scratch/en/blog/Hakyll-setup/
niceRoute :: Routes
niceRoute = customRoute createIndexRoute
  where createIndexRoute ident =
          takeDirectory p </> takeBaseName p </> "index.html"
          where p = toFilePath ident

-- drop "index.html" from given url field key
-- https://aherrmann.github.io/programming/2016/01/31/jekyll-style-urls-with-hakyll
dropIndexHtml :: String -> Context a
dropIndexHtml key = mapContext transform (urlField key) where
    transform url = case splitFileName url of
                        (p, "index.html") -> takeDirectory p
                        _                 -> url

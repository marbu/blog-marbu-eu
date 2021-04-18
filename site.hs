--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
import           Control.Monad (filterM)
import           Data.Monoid (mappend)
import           Data.Ord (comparing)
import           Data.Map (Map)
import qualified Data.Map as Map
import           Hakyll
import           Hakyll.Web.Tags


--------------------------------------------------------------------------------
main :: IO ()
main = hakyll $ do
    match "images/*" $ do
        route   idRoute
        compile copyFileCompiler

    match "css/*" $ do
        route   idRoute
        compile compressCssCompiler

    match (fromList ["about.md"]) $ do
        route   $ setExtension "html"
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/default.html" defaultContext
            >>= relativizeUrls

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
                    defaultContext
            let ctx = case Map.lookup tag myTagDescMap of
                 Nothing      -> minCtx
                 Just tagDesc -> minCtx `mappend` (constField "tagdesc" tagDesc)

            makeItem ""
                >>= loadAndApplyTemplate "templates/tag.html"     ctx
                >>= loadAndApplyTemplate "templates/default.html" ctx
                >>= relativizeUrls

    match "posts/*" $ do
        route $ setExtension "html"
        compile $ pandocCompiler
            >>= saveSnapshot "pristine"
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
                    defaultContext

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
                    constField "root" siteRoot

            makeItem ""
                >>= loadAndApplyTemplate "templates/sitemap.xml" sitemapCtx

    -- create tags page
    create ["tags.html"] $ do
        route idRoute
        compile $ do
            tagList <- renderTagList tags
            -- tagCloud <- renderTagCloud 80.0 200.0 tags
            let tagsCtx =
                    constField "taglist"  tagList     `mappend`
                    -- constField "tagcloud" tagCloud    `mappend`
                    constField "title" "Tags"         `mappend`
                    defaultContext

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
                =<< filterTag "fedora"
                =<< loadAllSnapshots "posts/*" "content"
            renderAtom myFedoraFeedConfig feedCtx posts

    create ["fedora/index.html"] $ do
        route idRoute
        compile $ makeItem $ Redirect "/tags/fedora.html"

    match "index.html" $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAllSnapshots "posts/*" "pristine"
            tagList <- renderTagList $ takeTags 6 $ sortTagsBy postNumTagSort tags
            let lastPosts = take 4 posts
                indexCtx =
                    listField "posts" (postCtxWithTags tags) (return lastPosts) `mappend`
                    constField "taglist" tagList                                `mappend`
                    defaultContext

            getResourceBody
                >>= applyAsTemplate indexCtx
                >>= loadAndApplyTemplate "templates/default.html" indexCtx
                >>= relativizeUrls

    match "templates/*" $ compile templateBodyCompiler


--------------------------------------------------------------------------------
siteRoot :: String
siteRoot = "https://blog.marbu.eu"

postCtx :: Context String
postCtx =
    constField "root" siteRoot       `mappend`
    dateField  "date"    "%e %B %Y"  `mappend`
    dateField  "isodate" "%Y-%m-%d"  `mappend`
    defaultContext

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

myFeedConfig :: FeedConfiguration
myFeedConfig = FeedConfiguration
    { feedTitle       = "blog.marbu.eu"
    , feedDescription = "marbu's blog feed"
    , feedAuthorName  = "Martin Bukatovič"
    , feedAuthorEmail = "blog@marbu.eu"
    , feedRoot        = siteRoot
    }

myFedoraFeedConfig :: FeedConfiguration
myFedoraFeedConfig = myFeedConfig
    { feedTitle       = "blog.marbu.eu/fedora"
    , feedDescription = "marbu's blog feed with fedora related posts only"
    }

filterTag :: String -> [Item a] -> Compiler [Item a]
filterTag tag items = filterM (itemHasTag tag) items
  where itemHasTag tag item = do
          let ii = itemIdentifier item
          tags <- getTags ii
          return $ tag `elem` tags

myTagDescMap :: Map String String
myTagDescMap = Map.fromList
  [ ("fedora",    "Fedora project related posts with a dedicated feed.")
  ]

--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
import           Data.Monoid (mappend)
import           Data.Ord (comparing)
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
            let ctx =
                    listField "posts" (postCtxWithTags tags) (return posts) `mappend`
                    constField "title" title                                `mappend`
                    defaultContext

            makeItem ""
                >>= loadAndApplyTemplate "templates/tag.html"     ctx
                >>= loadAndApplyTemplate "templates/default.html" ctx
                >>= relativizeUrls

    match "posts/*" $ do
        route $ setExtension "html"
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/post.html"    (postCtxWithTags tags)
            >>= saveSnapshot "content"
            >>= loadAndApplyTemplate "templates/default.html" (postCtxWithTags tags)
            >>= relativizeUrls

    create ["archive.html"] $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll "posts/*"
            let archiveCtx =
                    listField "posts" postCtx (return posts) `mappend`
                    constField "title" "Archive"             `mappend`
                    defaultContext

            makeItem ""
                >>= loadAndApplyTemplate "templates/archive.html" archiveCtx
                >>= loadAndApplyTemplate "templates/default.html" archiveCtx
                >>= relativizeUrls

    -- create tags page
    create ["tags.html"] $ do
        route idRoute
        compile $ do
            tagList <- renderTagList tags
            -- tagCloud <- renderTagCloud 80.0 200.0 tags
            let archiveCtx =
                    constField "taglist"  tagList     `mappend`
                    -- constField "tagcloud" tagCloud    `mappend`
                    constField "title" "Tags"         `mappend`
                    defaultContext

            makeItem ""
                >>= loadAndApplyTemplate "templates/tags.html"    archiveCtx
                >>= loadAndApplyTemplate "templates/default.html" archiveCtx
                >>= relativizeUrls

    create ["atom.xml"] $ do
        route idRoute
        compile $ do
            let feedCtx = postCtx `mappend` bodyField "description"
            posts <- fmap (take 10) . recentFirst
                =<< loadAllSnapshots "posts/*" "content"
            renderAtom myFeedConfiguration feedCtx posts

    match "index.html" $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll "posts/*"
            tagList <- renderTagList $ takeTags 5 $ sortTagsBy postNumTagSort tags
            let indexCtx =
                    listField "posts" postCtx (return posts) `mappend`
                    constField "taglist"  tagList            `mappend`
                    defaultContext

            getResourceBody
                >>= applyAsTemplate indexCtx
                >>= loadAndApplyTemplate "templates/default.html" indexCtx
                >>= relativizeUrls

    match "templates/*" $ compile templateBodyCompiler


--------------------------------------------------------------------------------
postCtx :: Context String
postCtx =
    dateField "date" "%B %e, %Y" `mappend`
    defaultContext

postCtxWithTags :: Tags -> Context String
postCtxWithTags tags = tagsField "tags" tags `mappend` postCtx

-- sort tags after number of posts in tag
postNumTagSort :: (String, [Identifier]) -> (String, [Identifier]) -> Ordering
postNumTagSort a b = comparing (length . snd) b a

-- get only given number of tags without the rest
takeTags :: Int -> Tags -> Tags
takeTags n tags = tags { tagsMap = (take n $ tagsMap tags) }

myFeedConfiguration :: FeedConfiguration
myFeedConfiguration = FeedConfiguration
    { feedTitle       = "blog.marbu.eu"
    , feedDescription = ""
    , feedAuthorName  = "marbu"
    , feedAuthorEmail = "blog@marbu.eu"
    , feedRoot        = "https://blog.marbu.eu"
    }

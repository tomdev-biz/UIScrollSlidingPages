Pod::Spec.new do |s|
  s.name = "UIScrollSlidingPages"
  s.version = "1.3"
  s.summary = "This control allows you to add multiple view controllers and have them scroll horizontally, each with a smaller header view."
  s.homepage = "https://github.com/TomThorpe/UIScrollSlidingPages"
  s.license = "MIT"
  s.platforms = {
    :ios => "6.0"
  }
  s.source = {
    :git => "https://github.com/TomThorpe/UIScrollSlidingPages.git",
    :tag => "1.3"
  }
  s.source_files = [
    "Classes",
    "UIScrollViewSlidingPages/Source/**/*.{h,m}"
  ]
  s.requires_arc = true
end


Pod::Spec.new do |s|
  s.name = 'StoreKISS'
  s.version = '0.2'
  s.license = 'MIT'
  s.summary = 'Lightweight wrapper for Apple\'s StoreKit framework created with KISS concept and love ❤.'
  s.homepage = 'https://github.com/mishakarpenko/StoreKISS'
  s.author = {
    'Misha Karpenko' => 'karpenko.misha@gmail.com'
  }
  s.source = {
    :git => 'https://github.com/6wunderkinder/StoreKISS.git', 
    :tag => 'v0.2'
  }
  s.source_files = 'StoreKISS/Classes'
  s.requires_arc = true

  s.framework = 'StoreKit'
end
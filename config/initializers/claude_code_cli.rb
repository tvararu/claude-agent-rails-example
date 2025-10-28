node_modules_bin = Rails.root.join("node_modules", ".bin").to_s
ENV["PATH"] = "#{node_modules_bin}:#{ENV['PATH']}" if Dir.exist?(
  node_modules_bin
)

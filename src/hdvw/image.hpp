#pragma once

#include <vulkan/vulkan.hpp>

#include <hdvw/device.hpp>
#include <hdvw/allocator.hpp>

#include <memory>

namespace hd {
    struct ImageCreateInfo {
        Allocator allocator;
        vk::Extent2D extent;
        vk::Format format = vk::Format::eR8G8B8A8Srgb;
        vk::ImageAspectFlags aspect = vk::ImageAspectFlagBits::eColor;
        uint32_t layers = 1;
        vk::ImageCreateFlags flags = vk::ImageCreateFlags{0};
        vk::ImageTiling tiling = vk::ImageTiling::eOptimal;
        vk::ImageUsageFlags imageUsage = vk::ImageUsageFlagBits::eSampled;
        VmaMemoryUsage memoryUsage = VMA_MEMORY_USAGE_GPU_ONLY;
    };

    class Image_t;
    typedef std::shared_ptr<Image_t> Image;

    class Image_t {
        private:
            vk::Image _image;
            VmaAllocation _imageMemory;

            vk::Extent2D _imageSize;
            vk::ImageLayout _layout;
            vk::Format _format;
            vk::ImageSubresourceRange _range;
            Allocator _allocator;

        public:
            static Image conjure(ImageCreateInfo const & ci) {
                return std::make_shared<Image_t>(ci);
            }

            Image_t(ImageCreateInfo const & ci);

            inline auto extent() {
                return _imageSize;
            }

            inline auto layout() {
                return _layout;
            }

            void setLayout(vk::ImageLayout layout);

            inline auto range() {
                return _range;
            }

            inline auto format() {
                return _format;
            }

            inline auto memory() {
                return _imageMemory;
            }

            inline auto raw() {
                return _image;
            }

            ~Image_t();
    };

    inline Image conjure(ImageCreateInfo const & ci) {
        return Image_t::conjure(ci);
    }

    struct ImageViewCreateInfo {
        vk::Image image = nullptr;
        Device device;
        vk::Format format = vk::Format::eR8G8B8A8Srgb;
        vk::ImageSubresourceRange range;
        vk::ImageViewType type = vk::ImageViewType::e2D;
    };

    class ImageView_t;
    typedef std::shared_ptr<ImageView_t> ImageView;

    class ImageView_t {
        private:
            vk::ImageView _view;
            vk::Device _device;

        public:
            static ImageView conjure(ImageViewCreateInfo const & ci) {
                return std::make_shared<ImageView_t>(ci);
            }

            ImageView_t(ImageViewCreateInfo const & ci);

            inline auto raw() {
                return _view;
            }

            vk::DescriptorImageInfo writeInfo(vk::ImageLayout layout) {
                vk::DescriptorImageInfo info{};
                info.imageView = _view;
                info.imageLayout = layout;

                return info;
            }

            ~ImageView_t();
    };

    inline ImageView conjure(ImageViewCreateInfo const & ci) {
        return ImageView_t::conjure(ci);
    }

    struct SamplerCreateInfo {
        Device device;
        vk::SamplerAddressMode addressMode = vk::SamplerAddressMode::eRepeat;
    };

    class Sampler_t;
    typedef std::shared_ptr<Sampler_t> Sampler;

    class Sampler_t {
        private:
            vk::Sampler _sampler;
            vk::Device _device;

        public:
            static Sampler conjure(SamplerCreateInfo const & ci) {
                return std::make_shared<Sampler_t>(ci);
            }

            Sampler_t(SamplerCreateInfo const & ci);

            inline auto raw() {
                return _sampler;
            }

            ~Sampler_t();
    };

    inline Sampler conjure(SamplerCreateInfo const & ci) {
        return Sampler_t::conjure(ci);
    }
}

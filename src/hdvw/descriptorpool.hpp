#pragma once

#include <vulkan/vulkan.hpp>

#include <hdvw/device.hpp>
#include <hdvw/descriptorlayout.hpp>
#include <hdvw/descriptorset.hpp>

#include <memory>
#include <utility>

namespace hd {
    struct DescriptorPoolCreateInfo {
        Device device;
        std::vector<std::pair<DescriptorLayout, uint32_t>> layouts;
        uint32_t instances = 1;
    };

    class DescriptorPool_t;
    typedef std::shared_ptr<DescriptorPool_t> DescriptorPool;

    class DescriptorPool_t {
        private:
            vk::DescriptorPool _pool;
            vk::Device _device;

            uint32_t _instances = 1;

        public:
            static DescriptorPool conjure(DescriptorPoolCreateInfo const & ci) {
                return std::make_shared<DescriptorPool_t>(ci);
            }

            DescriptorPool_t(DescriptorPoolCreateInfo const & ci);

            std::vector<DescriptorSet> allocate(uint32_t count, DescriptorLayout layout);

            inline auto raw() {
                return _pool;
            }

            ~DescriptorPool_t();
    };

    inline DescriptorPool conjure(DescriptorPoolCreateInfo const & ci) {
        return DescriptorPool_t::conjure(ci);
    }
}

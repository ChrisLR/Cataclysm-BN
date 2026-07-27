
#ifndef CATACLYSMBN_CATALUA_CREATURE_FILTERS_H
#define CATACLYSMBN_CATALUA_CREATURE_FILTERS_H
#include <memory>
#include <vector>
#include "sol/forward.hpp"

class monster;

std::vector<std::__shared_ptr<monster, __gnu_cxx::_S_single>> filter_monsters_from_lua(
            const sol::table &filters );


#endif //CATACLYSMBN_CATALUA_CREATURE_FILTERS_H

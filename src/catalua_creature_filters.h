
#ifndef CATACLYSMBN_CATALUA_CREATURE_FILTERS_H
#define CATACLYSMBN_CATALUA_CREATURE_FILTERS_H
#include <vector>
#include "sol/forward.hpp"

class monster;

std::vector<monster *> filter_monsters_from_lua( const sol::table &filters );


#endif //CATACLYSMBN_CATALUA_CREATURE_FILTERS_H

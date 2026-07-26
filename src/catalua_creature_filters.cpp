#include "catalua_creature_filters.h"

#include <functional>
#include <string>
#include <unordered_map>

#include "game.h"
#include "monster.h"

using LuaValue = sol::basic_object<sol::basic_reference<>>;
using MonsterVec = std::vector<monster*>;

struct FilterContext {
    LuaValue* value;
    monster* mon;
    MonsterVec &output;
    bool past_limit = false;
};

static bool filter_limit(FilterContext &context) {
    if (const auto limit_value = context.value->as<size_t>(); context.output.size() > limit_value) {
        context.past_limit = true;
        printf("[FILTER] Past Limit\n");
        return false;
    }
    return true;
}

static bool filter_type_ids(FilterContext &context) {
    const auto &ids = context.value->as<std::vector<mtype_id>>();

    if( std::ranges::find( ids, context.mon->type->id ) == ids.end() ) {
        printf("[FILTER] type_ids returned false for %s\n", context.mon->get_name().c_str());
        return false;
    }
    printf("[FILTER] type_ids returned true for %s\n", context.mon->get_name().c_str());
    return true;
}

static bool filter_faction_ids(FilterContext &context) {
    const auto &ids = context.value->as<std::vector<mfaction_id>>();

    if(const auto it = std::ranges::find( ids, context.mon->faction ); it == ids.end() ) {
        printf("[FILTER] faction_ids false for %s\n", context.mon->faction.id().c_str());
        return false;
    }
    printf("[FILTER] faction_ids returned true for %s\n", context.mon->get_name().c_str());
    return true;
}

static bool filter_species_ids(FilterContext &context) {
    const auto &filter_set = context.value->as<std::set<species_id>>();
    for( const auto &ms : context.mon->type->species ) {
        if( filter_set.contains( ms ) ) {
            printf("[FILTER] species_ids returned true for %s\n", context.mon->get_name().c_str());
            return true;
        }
    }
    printf("[FILTER] species_ids returned false for %s\n", context.mon->get_name().c_str());
    return false;
}

static bool filter_sees(FilterContext &context) {
    const auto &filter_set = context.value->as<std::vector<monster*>>();
    const auto mon_pos = context.mon->abs_pos();
    for( const auto &other_mon : filter_set ) {
        if( mon_pos != other_mon->abs_pos() && other_mon->sees(*context.mon)){
            printf("[FILTER] sees returned true for %s\n", context.mon->get_name().c_str());
            return true;
        }
    }
    printf("[FILTER] sees returned false for %s\n", context.mon->get_name().c_str());
    return false;
}

static bool filter_within_range_of(FilterContext &context) {
    const auto value_tbl = context.value->as<sol::table>();
    auto range = value_tbl["range"].get<float>();
    auto other_monsters = value_tbl["monsters"].get<std::vector<monster*>>();
    auto mpos = context.mon->abs_pos();
    for( const auto &other_mon : other_monsters ) {
        if (mpos == other_mon->abs_pos()) { continue; }
        if( abs(rl_dist_exact( mpos, other_mon->abs_pos() )) <= range ) {
            printf("[FILTER] within_range_of %f returned true for %s\n", range, context.mon->get_name().c_str());
            return true;
        }
    }
    printf("[FILTER] within_range_of %f returned false for %s\n", range, context.mon->get_name().c_str());
    return false;
}

static bool filter_hostile_to(FilterContext &context) {
    const auto &filter_set = context.value->as<std::vector<monster*>>();
    auto mpos = context.mon->abs_pos();
    for( const auto &other_mon : filter_set ) {
        if (mpos == other_mon->abs_pos()) { continue; }
        if( context.mon->attitude_to( *other_mon ) == A_HOSTILE) {
            printf("[FILTER] hostile_to returned true for %s against %s\n", context.mon->get_name().c_str(), other_mon->get_name().c_str());
            return true;
        }
    }
    printf("[FILTER] hostile_to returned false for %s\n", context.mon->get_name().c_str());
    return false;
}

static const std::unordered_map<std::string, std::function<bool(FilterContext &context)>> handlers = {
    {"limit", [](FilterContext &context) -> bool { return filter_limit(context);}},
    {"type_ids", [](FilterContext &context) -> bool { return filter_type_ids(context);}},
    {"faction_ids", [](FilterContext &context) -> bool { return filter_faction_ids(context);}},
    {"species_ids", [](FilterContext &context) -> bool { return filter_species_ids(context);}},
    {"sees", [](FilterContext &context) -> bool { return filter_sees(context);}},
    {"within_range_of", [](FilterContext &context) -> bool { return filter_within_range_of(context);}},
    {"hostile_to", [](FilterContext &context) -> bool { return filter_hostile_to(context);}},
};

std::vector<monster*> filter_monsters_from_lua(sol::table &filters) {
    std::vector<monster*> monsters;
    FilterContext context = {
        .value = nullptr,
        .mon = nullptr,
        .output = monsters
    };
    for (monster& mon : g->all_monsters()) {
        context.mon = &mon;
        bool matching = true;
        for( auto &&[key, value] : filters ) {
            context.value = &value;
            auto str_key = key.as<std::string>();
            if (auto it = handlers.find(str_key); it != handlers.end()) {
                if (auto filter_result = it->second(context); !filter_result) {
                    matching = false;
                    break;
                }
            } else {
                debugmsg("Unknown filter %s", str_key.c_str());
            }
        }
        if (matching) {
            monsters.push_back(*mon);
        }
        if (context.past_limit) {
            break;
        }
    }
    return monsters;
}
